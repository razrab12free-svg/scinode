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
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from . import metrics as m
from .client import OpenAlexClient, OpenAlexError

SCHEMA = 1
FWCI_FULL_LIMIT = 5000  # до стольких работ FWCI берём у всех, больше — выборка
FWCI_SAMPLE = 5000
FWCI_SEED = "42"
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


def _fwci(client, flt: str) -> dict:
    first = client.get(
        "/works", {"filter": flt, "select": "id,fwci", "per_page": "200", "cursor": "*"}
    )
    total = (first.get("meta") or {}).get("count") or 0
    if total <= FWCI_FULL_LIMIT:
        vals = [w.get("fwci") for w in first.get("results") or []]
        cur = (first.get("meta") or {}).get("next_cursor")
        while cur and first.get("results"):
            r = client.get(
                "/works",
                {"filter": flt, "select": "id,fwci", "per_page": "200", "cursor": cur},
            )
            res = r.get("results") or []
            if not res:
                break
            vals += [w.get("fwci") for w in res]
            cur = (r.get("meta") or {}).get("next_cursor")
        return m.fwci_stats(vals, False, total)
    vals = []
    for page in range(1, FWCI_SAMPLE // 200 + 1):
        r = client.get(
            "/works",
            {
                "filter": flt,
                "select": "id,fwci",
                "per_page": "200",
                "sample": str(FWCI_SAMPLE),
                "seed": FWCI_SEED,
                "page": str(page),
            },
        )
        res = r.get("results") or []
        if not res:
            break
        vals += [w.get("fwci") for w in res]
    return m.fwci_stats(vals, True, total)


def build_report(
    client,
    base: str,
    first: int,
    last: int,
    years_from: int,
    years_to: int,
    exclude: set[str],
    home_country: str,
) -> dict:
    """Все разделы отчёта по набору работ base (фильтр OpenAlex)."""
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

    top_src = m.group_list(_works(client, W, "primary_location.source.id"))[:20]
    sdata = _batch(
        client,
        "/sources",
        [s["id"] for s in top_src],
        "id,display_name,type,issn_l,is_in_doaj,is_oa,host_organization_name,"
        "country_code,summary_stats",
    )
    journals = [m.journal_row(sdata[s["id"]], s["n"]) for s in top_src if s["id"] in sdata]

    sub_total = m.group_list(_works(client, W, "primary_topic.subfield.id"))
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
        "url": inst.get("homepage_url") or "",
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
            )
        except (OpenAlexError, KeyError, TypeError, ValueError) as e:
            return meta, str(e)
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
    except OpenAlexError as e:
        failed.append({"id": country, "error": str(e)})

    index = {
        **common,
        "min_works": min_works,
        "fwci_full_limit": FWCI_FULL_LIMIT,
        "fwci_sample": FWCI_SAMPLE,
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
    p.add_argument("--workers", type=int, default=4)
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
    total = len(idx["orgs"]) + len(idx["failed"])
    print(
        f"Готово: {len(idx['orgs'])} организаций, ошибок {len(idx['failed'])}, "
        f"запросов {client.calls}"
    )
    # Если сломалось больше 10 % — не публикуем неполные данные.
    if total == 0 or len(idx["failed"]) > max(1, total // 10):
        print("Слишком много ошибок — публикация отменена.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
