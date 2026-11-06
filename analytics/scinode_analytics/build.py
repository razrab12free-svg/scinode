"""Сборка отчётов «Scinode Аналитика» по организациям страны.

Запуск:  python -m scinode_analytics.build --out site
Результат (публикуется на GitHub Pages):
  site/analytics/v1/index.json        — список организаций и параметры расчёта
  site/analytics/v1/orgs/<id>.json    — отчёт по организации (и по стране: UZ.json)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import threading
import urllib.parse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from . import metrics as m
from .client import BudgetExhausted, OpenAlexClient, OpenAlexError

SCHEMA = 1
EXCLUDED_TYPES = {"company"}
INST_FIELDS = (
    "id,display_name,display_name_acronyms,display_name_alternatives,type,ror,"
    "geo,homepage_url,counts_by_year,summary_stats,works_count,cited_by_count,"
    "associated_institutions"
)


def window(today: dt.date) -> tuple[int, int]:
    """5 последних полных лет: в 2026 году — 2021–2025."""
    last = today.year - 1
    return last - 4, last


def _works(client, flt: str, group_by: str) -> dict:
    return client.get("/works", {"filter": flt, "group_by": group_by})


def _batch(client, path: str, ids: list[str], select: str) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for i in range(0, len(ids), 50):
        part = ids[i : i + 50]
        if not part:
            continue
        r = client.get(
            path,
            {
                "filter": "openalex:" + "|".join(part),
                "select": select,
                "per_page": "50",
            },
        )
        for x in r.get("results") or []:
            out[m.short_id(x.get("id"))] = x
    return out


def _count(client, flt: str) -> int:
    r = client.get("/works", {"filter": flt, "per_page": "1", "select": "id"})
    n = (r.get("meta") or {}).get("count")
    return n if isinstance(n, int) else 0


def _fwci(client, flt: str) -> dict:
    """Доли работ по FWCI — фильтрами, без скачивания списков работ."""
    return m.fwci_shares(
        known=_count(client, flt + ",fwci:>-1"),
        cited=_count(client, flt + ",fwci:>0"),
        above1=_count(client, flt + ",fwci:>1"),
    )


_crossref_cache: dict[str, dict] = {}
_crossref_lock = threading.Lock()

# Запросов OpenAlex на организацию и на страну (с запасом) — для проверки
# дневного лимита ключа перед началом расчёта.
REQUESTS_PER_ORG = 60
REQUESTS_COUNTRY = 60

# Сколько самых цитируемых работ организации проверять (по 1 запросу
# OpenAlex и 1 запросу OpenCitations на работу).
CHECK_WORKS = 10


def _apc(client, flt: str) -> dict:
    """Оценка расходов на APC: group_by по цене, все страницы (cursor)."""
    pages = []
    cursor = "*"
    for _ in range(20):
        r = client.get(
            "/works",
            {
                "filter": flt + ",apc_paid.value_usd:>0",
                "group_by": "apc_paid.value_usd",
                "per_page": "200",
                "cursor": cursor,
            },
        )
        pages.append(r)
        cursor = (r.get("meta") or {}).get("next_cursor")
        if not cursor or not m.groups(r):
            break
    return m.apc_sum(pages)


def _prolific(client, flt: str, first: int, last: int, home_country: str) -> dict:
    """Сверхплодовитые авторы: больше 72 статей, обзоров и докладов за год.

    Работы мегаколлабораций (больше 100 авторов) не считаются — как у
    Иоаннидиса (физика частиц иначе даёт сотни «работ» в год). Кандидаты —
    20 самых активных авторов набора; их годовой итог считается по ВСЕМ
    местам работы. В отчёт идут только числа, без имён.
    """
    typed = f"type:{m.PROLIFIC_TYPES},authors_count:<{m.MEGA_AUTHORS + 1}"
    top = m.group_list(_works(client, f"{flt},{typed}", "authorships.author.id"))[:20]
    here = {a["id"]: a["n"] for a in top}
    adata = _batch(
        client,
        "/authors",
        list(here),
        "id,display_name,orcid,works_count,cited_by_count,summary_stats,"
        "last_known_institutions,counts_by_year",
    )
    out = []
    for aid in m.prolific_candidates(adata, first, last)[:10]:
        yc = m.group_counts(
            _works(
                client,
                f"authorships.author.id:{aid},publication_year:{first}-{last},{typed}",
                "publication_year",
            )
        )
        r = m.prolific_row(
            here.get(aid, 0), m.works_in_country(adata[aid], home_country), yc
        )
        if r:
            out.append(r)
    out.sort(key=lambda r: (-r["max"], -r["n"], r["max_year"]))
    return {"threshold": m.PROLIFIC_PER_YEAR, "checked": len(adata), "authors": out}


def _crossref(client, issn: str) -> dict:
    """Журнал в Crossref (с кэшем: одни и те же журналы у многих вузов)."""
    with _crossref_lock:
        hit = _crossref_cache.get(issn)
    if hit is not None:
        return hit
    try:
        res = m.crossref_journal(
            client.get_url(
                "https://api.crossref.org/works?rows=0&facet=publisher-name:1"
                f"&filter=issn:{urllib.parse.quote(issn)}"
            )
        )
    except OpenAlexError:
        res = {}
    with _crossref_lock:
        _crossref_cache[issn] = res
    return res


def _citation_check(client, flt: str, exclude: set[str]) -> dict:
    r = client.get(
        "/works",
        {
            "filter": flt + f",cited_by_count:>{m.CHECK_MIN_CITES - 1}",
            "sort": "cited_by_count:desc",
            "per_page": str(CHECK_WORKS),
            "select": "id,doi,display_name,publication_year,cited_by_count,"
            "primary_location",
        },
    )
    rows = []
    for w in r.get("results") or []:
        wid = m.short_id(w.get("id"))
        inst = m.citing_institutions(
            client.get(
                "/works",
                {"filter": f"cites:{wid}", "group_by": "authorships.institutions.lineage"},
            ),
            exclude,
        )
        doi = str(w.get("doi") or "").replace("https://doi.org/", "")
        oc = {"n": 0, "author_sc": 0, "journal_sc": 0}
        if doi:
            try:
                oc = m.oc_counts(
                    client.get_url(
                        "https://api.opencitations.net/index/v2/citations/doi:"
                        + urllib.parse.quote(doi, safe="/:")
                    )
                )
            except OpenAlexError:
                pass
        rows.append(m.work_check(w, oc, inst))
    return m.citation_check_summary(rows)


def build_report(
    client,
    base: str,
    first: int,
    last: int,
    years_from: int,
    years_to: int,
    exclude: set[str],
    home_country: str,
    lead_id: str | None = None,
) -> dict:
    """Все разделы отчёта по набору работ base (фильтр OpenAlex).

    [lead_id] — организация, для которой считаются «ведущие» работы
    (corresponding_institution_ids); для страны такого фильтра нет.
    """
    W = f"{base},publication_year:{first}-{last}"
    Y = f"{base},publication_year:{years_from}-{years_to}"

    years = m.years_table(
        m.group_counts(_works(client, Y, "publication_year")),
        m.group_counts(_works(client, Y + ",type:article", "publication_year")),
        m.group_counts(_works(client, Y + ",type:conference-paper", "publication_year")),
        m.group_counts(_works(client, Y + ",open_access.is_oa:true", "publication_year")),
        years_from,
        years_to,
    )
    types = m.group_list(_works(client, W, "type"))
    total = sum(t["n"] for t in types)
    oa_status = m.group_list(_works(client, W, "open_access.oa_status"))

    t10, known10 = m.bool_counts(
        _works(client, W, "citation_normalized_percentile.is_in_top_10_percent")
    )
    t1, known1 = m.bool_counts(
        _works(client, W, "citation_normalized_percentile.is_in_top_1_percent")
    )
    citation = {
        "known": known10,
        "top10": t10,
        "top1": t1,
        "pp_top10": m.share(t10, known10),
        "pp_top1": m.share(t1, known1),
        "fwci": _fwci(client, W),
    }

    # Ведущие работы: автор для переписки — из этой организации. Без них
    # показатели завышает «гостевое» соавторство в чужих статьях.
    L = f"{W},corresponding_institution_ids:{lead_id}" if lead_id else None
    if L:
        lt10, lknown10 = m.bool_counts(
            _works(client, L, "citation_normalized_percentile.is_in_top_10_percent")
        )
        lt1, lknown1 = m.bool_counts(
            _works(client, L, "citation_normalized_percentile.is_in_top_1_percent")
        )
        lead_n = _count(client, L)
        citation["lead"] = {
            "works": lead_n,
            "share": m.share(lead_n, total),
            "known": lknown10,
            "top10": lt10,
            "top1": lt1,
            "pp_top10": m.share(lt10, lknown10),
            "pp_top1": m.share(lt1, lknown1),
        }
    # Мегаколлаборации (больше 100 авторов): несколько таких статей
    # заметно поднимают топ-10 % небольшой организации.
    mt10, mknown = m.bool_counts(
        _works(
            client,
            f"{W},authors_count:>{m.MEGA_AUTHORS}",
            "citation_normalized_percentile.is_in_top_10_percent",
        )
    )
    citation["mega"] = {
        "works": _count(client, f"{W},authors_count:>{m.MEGA_AUTHORS}"),
        "known": mknown,
        "top10": mt10,
        "pp_top10_without": m.share(t10 - mt10, known10 - mknown),
    }
    integrity = {
        "retracted": _count(client, f"{W},is_retracted:true"),
        "source_types": m.group_list(
            _works(client, W, "primary_location.source.type")
        ),
    }

    cdc = m.group_counts(_works(client, W, "countries_distinct_count"))
    intl = sum(n for k, n in cdc.items() if k.isdigit() and int(k) > 1)
    cdc_total = sum(cdc.values())
    doaj, doaj_known = m.bool_counts(
        _works(client, W, "primary_location.source.is_in_doaj")
    )

    countries = [
        c
        for c in m.group_list(_works(client, W, "authorships.institutions.country_code"))
        if c["id"].upper() != home_country.upper()
    ][:30]

    lineage = m.group_list(_works(client, W, "authorships.institutions.lineage"))
    cand = [x["id"] for x in lineage if x["id"] not in exclude][:40]
    info = {
        k: {
            "name": " ".join(str(v.get("display_name") or "").split()),
            "country": v.get("country_code") or "",
            "type": v.get("type") or "",
        }
        for k, v in _batch(
            client, "/institutions", cand, "id,display_name,country_code,type"
        ).items()
    }
    partners = m.partner_orgs(lineage, exclude, info)

    top_auth = m.group_list(_works(client, W, "authorships.author.id"))[:20]
    adata = _batch(
        client,
        "/authors",
        [a["id"] for a in top_auth],
        "id,display_name,orcid,works_count,cited_by_count,summary_stats,"
        "last_known_institutions",
    )
    authors = [m.author_row(adata[a["id"]], a["n"]) for a in top_auth if a["id"] in adata]
    prolific = _prolific(client, W, first, last, home_country)

    # Цели устойчивого развития, языки, фонды, оценка расходов на APC.
    sdg = m.sdg_block(
        _works(client, W, "sustainable_development_goals.id"),
        _count(client, W + ",sustainable_development_goals.id:!null"),
        total,
    )
    languages = m.languages_list(_works(client, W, "language"))
    fund_groups = _works(client, W, "funders.id")
    fund_ids = [g["id"] for g in m.group_list(fund_groups)[:15]]
    funding = m.funders_block(
        fund_groups,
        _count(client, W + ",funders.id:!null"),
        total,
        _batch(client, "/funders", fund_ids, "id,display_name,country_code"),
    )
    apc = _apc(client, W)
    if L:
        apc["lead"] = _apc(client, L)

    top_src = m.group_list(_works(client, W, "primary_location.source.id"))[:20]
    sdata = _batch(
        client,
        "/sources",
        [s["id"] for s in top_src],
        "id,display_name,type,issn_l,is_in_doaj,is_oa,host_organization_name,"
        "country_code,summary_stats,counts_by_year",
    )
    journals = [
        m.journal_row(sdata[s["id"]], s["n"], last)
        for s in top_src
        if s["id"] in sdata
    ]
    # Crossref: есть ли журнал (по ISSN) в главном реестре DOI, издатель.
    for j in journals:
        if j["issn"] and j["type"] == "journal":
            j.update(_crossref(client, j["issn"]))

    # Самые цитируемые работы: самоцитирование (OpenCitations) и откуда
    # приходят цитирования (OpenAlex) — признаки «накрутки» и «картелей».
    citation_check = _citation_check(client, W, exclude) if lead_id else None

    sub_total = m.group_list(_works(client, W, "primary_topic.subfield.id"))
    lead_sub = None
    if L:
        lead_sub = (
            m.group_counts(_works(client, L, "primary_topic.subfield.id")),
            m.group_counts(
                _works(
                    client,
                    L + ",citation_normalized_percentile.is_in_top_10_percent:true",
                    "primary_topic.subfield.id",
                )
            ),
            m.group_counts(
                _works(
                    client,
                    L + ",citation_normalized_percentile.is_in_top_10_percent:false",
                    "primary_topic.subfield.id",
                )
            ),
        )
    topics = m.topics_table(
        {x["id"]: x["n"] for x in sub_total},
        m.group_counts(
            _works(
                client,
                W + ",citation_normalized_percentile.is_in_top_10_percent:true",
                "primary_topic.subfield.id",
            )
        ),
        m.group_counts(
            _works(
                client,
                W + ",citation_normalized_percentile.is_in_top_10_percent:false",
                "primary_topic.subfield.id",
            )
        ),
        {x["id"]: x["name"] for x in sub_total},
        lead=lead_sub[0] if lead_sub else None,
        lead_top10=lead_sub[1] if lead_sub else None,
        lead_no_top10=lead_sub[2] if lead_sub else None,
    )

    return {
        "works": total,
        "years": years,
        "types": types,
        "oa": {
            "n": sum(r["oa"] for r in years if first <= r["y"] <= last),
            "status": oa_status,
        },
        "citation": citation,
        "collab": {
            "intl": intl,
            "intl_share": m.share(intl, cdc_total),
            "countries": countries,
            "partners": partners,
        },
        "authors": authors,
        "journals": {
            "doaj": doaj,
            "known": doaj_known,
            "doaj_share": m.share(doaj, doaj_known),
            "top": journals,
        },
        "topics": topics,
        "integrity": integrity,
        "prolific": prolific,
        "sdg": sdg,
        "languages": languages,
        "funding": funding,
        "apc": apc,
        **({"citation_check": citation_check} if citation_check else {}),
    }


def org_meta(inst: dict, first: int, last: int) -> dict:
    s = inst.get("summary_stats") or {}
    geo = inst.get("geo") or {}
    return {
        "id": m.short_id(inst.get("id")),
        "name": " ".join(str(inst.get("display_name") or "").split()),
        "acronyms": inst.get("display_name_acronyms") or [],
        "alt": inst.get("display_name_alternatives") or [],
        "type": inst.get("type") or "",
        "ror": m.short_id(inst.get("ror")) if inst.get("ror") else "",
        "city": geo.get("city") or "",
        "lat": geo.get("latitude"),
        "lon": geo.get("longitude"),
        "url": m.safe_url(inst.get("homepage_url")),
        "works_window": m.works_in(inst, first, last),
        "works_total": inst.get("works_count") or 0,
        "citations_total": inst.get("cited_by_count") or 0,
        "h": s.get("h_index") or 0,
        "i10": s.get("i10_index") or 0,
    }


def list_orgs(client, country: str, min_works: int, first: int, last: int) -> list[dict]:
    out: list[dict] = []
    cur = "*"
    while cur:
        r = client.get(
            "/institutions",
            {
                "filter": f"country_code:{country}",
                "select": INST_FIELDS,
                "per_page": "200",
                "cursor": cur,
            },
        )
        res = r.get("results") or []
        if not res:
            break
        out += res
        cur = (r.get("meta") or {}).get("next_cursor")
    sel = [
        i
        for i in out
        if (i.get("type") or "") not in EXCLUDED_TYPES
        and m.works_in(i, first, last) >= min_works
    ]
    sel.sort(key=lambda i: (-m.works_in(i, first, last), m.short_id(i.get("id"))))
    return sel


def build_all(
    client,
    out: Path,
    country: str = "UZ",
    min_works: int = 100,
    today: dt.date | None = None,
    only: list[str] | None = None,
    limit: int | None = None,
    workers: int = 4,
    log=print,
) -> dict:
    today = today or dt.date.today()
    first, last = window(today)
    years_from, years_to = last - 9, today.year
    orgs = list_orgs(client, country, min_works, first, last)
    if only:
        orgs = [o for o in orgs if m.short_id(o.get("id")) in only]
    if limit:
        orgs = orgs[:limit]
    # Хватит ли дневного лимита ключа на весь расчёт? Иначе — не начинать:
    # обрыв на середине оставил бы неполные данные.
    need = len(orgs) * REQUESTS_PER_ORG + REQUESTS_COUNTRY
    left = getattr(client, "remaining", None)
    if left is not None and left < need:
        raise BudgetExhausted(
            f"нужно около {need} запросов OpenAlex, осталось {left}"
        )
    base_dir = out / "analytics" / f"v{SCHEMA}"
    (base_dir / "orgs").mkdir(parents=True, exist_ok=True)
    common = {
        "schema": SCHEMA,
        "generated": today.isoformat(),
        "source": "OpenAlex",
        "window": [first, last],
        "years": [years_from, years_to],
        "country": country,
    }

    def one(inst: dict) -> tuple[dict, str | None]:
        meta = org_meta(inst, first, last)
        try:
            rep = build_report(
                client,
                f"authorships.institutions.lineage:{meta['id']}",
                first,
                last,
                years_from,
                years_to,
                {meta["id"]} | m.children_of(inst),
                country,
                lead_id=meta["id"],
            )
        except BudgetExhausted:
            raise
        except (OpenAlexError, KeyError, TypeError, ValueError) as e:
            return meta, str(e)
        if meta.get("ror"):
            try:
                ror = m.ror_record(
                    client.get_url(
                        f"https://api.ror.org/v2/organizations/{meta['ror']}"
                    )
                )
                if ror:
                    meta["ror_data"] = ror
            except OpenAlexError:
                pass
        doc = {**common, "org": meta, **rep}
        (base_dir / "orgs" / f"{meta['id']}.json").write_text(
            json.dumps(doc, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
        )
        return meta, None

    done: list[dict] = []
    failed: list[dict] = []
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for meta, err in pool.map(one, orgs):
            if err:
                failed.append({"id": meta["id"], "error": err})
                log(f"  ! {meta['id']} {meta['name']}: {err}")
            else:
                done.append(meta)
                log(f"  ✓ {meta['id']} {meta['name']}")

    # Вся страна — для сравнения организации со средним по стране.
    national = None
    try:
        rep = build_report(
            client,
            f"authorships.institutions.country_code:{country}",
            first,
            last,
            years_from,
            years_to,
            set(),
            country,
        )
        national = {**common, "org": {"id": country, "name": country, "type": "country"}, **rep}
        (base_dir / "orgs" / f"{country}.json").write_text(
            json.dumps(national, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
    except BudgetExhausted:
        raise
    except OpenAlexError as e:
        failed.append({"id": country, "error": str(e)})

    index = {
        **common,
        "min_works": min_works,
        "min_topic_works": m.MIN_TOPIC_WORKS,
        "national": national is not None,
        "orgs": done,
        "failed": failed,
    }
    (base_dir / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    return index


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", default="site")
    p.add_argument("--country", default="UZ")
    p.add_argument("--min-works", type=int, default=100)
    p.add_argument("--today", help="дата расчёта ГГГГ-ММ-ДД (для проверки)")
    p.add_argument("--only", nargs="*", help="только эти организации (I…)")
    p.add_argument("--limit", type=int)
    p.add_argument("--record", help="записать ответы OpenAlex в папку (образцы)")
    p.add_argument("--workers", type=int, default=6)
    a = p.parse_args(argv)

    client = OpenAlexClient(record_dir=Path(a.record) if a.record else None)
    if not client.api_key:
        print(
            "Нет ключа OpenAlex: задайте секрет OPENALEX_API_KEY "
            "(Settings → Secrets and variables → Actions).",
            file=sys.stderr,
        )
        return 2
    today = dt.date.fromisoformat(a.today) if a.today else None
    try:
        # Один лёгкий запрос, чтобы узнать остаток дневного лимита ключа.
        client.get("/works", {"per_page": "1", "select": "id"})
    except BudgetExhausted as e:
        print(f"Расчёт не начат: {e}. Данные на сайте не изменились.", file=sys.stderr)
        return 3
    try:
        idx = build_all(
            client,
            Path(a.out),
            a.country,
            a.min_works,
            today,
            a.only,
            a.limit,
            a.workers,
        )
    except BudgetExhausted as e:
        print(
            f"Расчёт остановлен: {e}. Ничего не опубликовано — на сайте остаются "
            "прошлые данные. Запустите снова после 00:00 UTC.",
            file=sys.stderr,
        )
        return 3
    total = len(idx["orgs"]) + len(idx["failed"])
    print(
        f"Готово: {len(idx['orgs'])} организаций, ошибок {len(idx['failed'])}, "
        f"запросов OpenAlex {client.calls}, других API {client.ext_calls}"
    )
    # Если сломалось больше 10 % — не публикуем неполные данные.
    if total == 0 or len(idx["failed"]) > max(1, total // 10):
        print("Слишком много ошибок — публикация отменена.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
