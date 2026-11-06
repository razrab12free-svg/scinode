"""Разбор ответов OpenAlex и расчёт показателей. Только чистые функции.

Методика (подробно — analytics/README.md):
- окно для показателей качества — 5 последних полных лет;
- PP(top 10%) и PP(top 1%) — доля работ в мировом топе своей области
  (поле citation_normalized_percentile), как в Лейденском рейтинге (CWTS);
  знаменатель — работы, для которых OpenAlex посчитал процентиль;
- FWCI — нормированная цитируемость: доли работ с FWCI > 0 (процитированы)
  и FWCI > 1 (выше мирового уровня); медиана почти всегда 0 и не показывается;
- сильное направление — раздел (subfield), где по ВЕДУЩИМ работам
  организации (автор для переписки из неё) нижняя граница 95 % интервала
  PP(top 10%) выше 10 % и таких работ не меньше MIN_TOPIC_WORKS;
- «ведущие» работы, мегаколлаборации (> MEGA_AUTHORS авторов) и отозванные
  статьи показываются отдельно — это защита от завышения показателей.
"""

from __future__ import annotations

import html
import math
from urllib.parse import unquote

MIN_TOPIC_WORKS = 30

# Работ с числом авторов больше этого — «мегаколлаборации» (CERN и т. п.).
MEGA_AUTHORS = 100


def wilson_low(k: int, n: int, z: float = 1.96) -> float | None:
    """Нижняя граница 95 % доверительного интервала доли k из n (Уилсон).

    Нужна, чтобы 5 удачных статей из 30 не объявлялись «сильным
    направлением»: доля выше 10 % засчитывается, только если выше 10 %
    даже нижняя граница.
    """
    if n <= 0:
        return None
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    r = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return round((c - r) / d, 4)


def short_id(v: object) -> str:
    """https://openalex.org/I47151758 → I47151758; …/countries/UZ → UZ."""
    s = "" if v is None else str(v)
    # Ключи OpenAlex бывают закодированы: …/source-types/ebook%20platform.
    return unquote(s.rstrip("/").rsplit("/", 1)[-1])


def groups(resp: dict) -> list[dict]:
    g = resp.get("group_by") if isinstance(resp, dict) else None
    return g if isinstance(g, list) else []


def group_counts(resp: dict) -> dict[str, int]:
    """Ответ group_by → {ключ: число работ}."""
    out: dict[str, int] = {}
    for x in groups(resp):
        k = short_id(x.get("key"))
        n = x.get("count")
        if k and isinstance(n, int):
            out[k] = out.get(k, 0) + n
    return out


def group_list(resp: dict) -> list[dict]:
    """Ответ group_by → [{id, name, n}] по убыванию."""
    out = []
    for x in groups(resp):
        k = short_id(x.get("key"))
        n = x.get("count")
        if not k or not isinstance(n, int) or k in ("unknown", "null"):
            continue
        name = " ".join(str(x.get("key_display_name") or "").split())
        out.append({"id": k, "name": name, "n": n})
    out.sort(key=lambda e: (-e["n"], e["id"]))
    return out


def bool_counts(resp: dict) -> tuple[int, int]:
    """group_by по полю true/false → (true, true + false)."""
    c = group_counts(resp)
    t = c.get("true", 0)
    return t, t + c.get("false", 0)


def share(part: int, whole: int) -> float | None:
    return round(part / whole, 4) if whole > 0 else None


def years_table(
    all_: dict[str, int],
    article: dict[str, int],
    conference: dict[str, int],
    oa: dict[str, int],
    first: int,
    last: int,
) -> list[dict]:
    rows = []
    for y in range(first, last + 1):
        k = str(y)
        a = all_.get(k, 0)
        art = article.get(k, 0)
        conf = conference.get(k, 0)
        rows.append(
            {
                "y": y,
                "all": a,
                "article": art,
                "conference": conf,
                "other": max(a - art - conf, 0),
                "oa": oa.get(k, 0),
            }
        )
    return rows


def fwci_shares(known: int, cited: int, above1: int) -> dict:
    """FWCI: сколько работ хоть раз процитировано (FWCI > 0) и сколько
    цитируется выше мирового уровня своей области (FWCI > 1).

    Медиану не показываем: у большинства организаций больше половины работ
    ещё не цитировались, и медиана равна 0 — она ничего не различает.
    """
    return {
        "known": known,
        "cited": cited,
        "above1": above1,
        "cited_share": share(cited, known),
        "above1_share": share(above1, known),
    }


def topics_table(
    total: dict[str, int],
    top10: dict[str, int],
    no_top10: dict[str, int],
    names: dict[str, str],
    limit: int = 25,
    lead: dict[str, int] | None = None,
    lead_top10: dict[str, int] | None = None,
    lead_no_top10: dict[str, int] | None = None,
) -> list[dict]:
    """Направления (разделы OpenAlex) по числу работ.

    «Сильное» направление считается по ВЕДУЩИМ работам организации
    (автор для переписки — из неё), если они известны: иначе в «сильные»
    попадают темы, где организация лишь один из многих соавторов чужих
    высокоцитируемых статей. Условия: не меньше MIN_TOPIC_WORKS ведущих
    работ с процентилем и нижняя граница доли в топ-10 % выше 10 %.
    """
    rows = []
    for k, n in total.items():
        t = top10.get(k, 0)
        known = t + no_top10.get(k, 0)
        pp = share(t, known)
        row = {
            "id": k,
            "name": names.get(k, ""),
            "n": n,
            "top10": t,
            "known": known,
            "pp_top10": pp,
        }
        if lead is not None:
            lt = (lead_top10 or {}).get(k, 0)
            lk = lt + (lead_no_top10 or {}).get(k, 0)
            low = wilson_low(lt, lk)
            row.update(
                {
                    "lead": lead.get(k, 0),
                    "lead_share": share(lead.get(k, 0), n),
                    "lead_known": lk,
                    "lead_top10": lt,
                    "lead_pp_top10": share(lt, lk),
                    "strong": bool(
                        lk >= MIN_TOPIC_WORKS and low is not None and low > 0.10
                    ),
                }
            )
        else:
            low = wilson_low(t, known)
            row["strong"] = bool(
                known >= MIN_TOPIC_WORKS and low is not None and low > 0.10
            )
        rows.append(row)
    rows.sort(key=lambda e: (-e["n"], e["id"]))
    return rows[:limit]


def partner_orgs(
    lineage: list[dict],
    exclude: set[str],
    info: dict[str, dict],
    limit: int = 25,
) -> list[dict]:
    """Организации-соавторы без самой организации и её подразделений."""
    out = []
    for x in lineage:
        if x["id"] in exclude:
            continue
        i = info.get(x["id"], {})
        out.append(
            {
                "id": x["id"],
                "name": i.get("name") or x["name"],
                "country": i.get("country", ""),
                "type": i.get("type", ""),
                "n": x["n"],
            }
        )
        if len(out) >= limit:
            break
    return out


def author_row(a: dict, n: int) -> dict:
    s = a.get("summary_stats") or {}
    lki = a.get("last_known_institutions") or []
    return {
        "id": short_id(a.get("id")),
        "name": " ".join(str(a.get("display_name") or "").split()),
        "orcid": short_id(a.get("orcid")) if a.get("orcid") else "",
        "n": n,
        "works": a.get("works_count") or 0,
        "citations": a.get("cited_by_count") or 0,
        "h": s.get("h_index") or 0,
        "inst": " ".join(str(lki[0].get("display_name") or "").split())
        if lki and isinstance(lki[0], dict)
        else "",
    }


def journal_row(s: dict, n: int, last: int | None = None) -> dict:
    st = s.get("summary_stats") or {}
    return {
        "id": short_id(s.get("id")),
        "name": " ".join(str(s.get("display_name") or "").split()),
        "type": s.get("type") or "",
        "issn": s.get("issn_l") or "",
        "doaj": bool(s.get("is_in_doaj")),
        "oa": bool(s.get("is_oa")),
        "publisher": s.get("host_organization_name") or "",
        "country": s.get("country_code") or "",
        "h": st.get("h_index") or 0,
        "mean2y": round(st.get("2yr_mean_citedness") or 0, 3),
        "n": n,
        "growth": journal_growth(s.get("counts_by_year") or [], last),
    }


# Рост объёма журнала: работ в последнем полном году к году тремя годами
# раньше. Резкий рост (в 3 раза и больше, от 500 работ в год) — частый
# признак «конвейера» публикаций; это повод проверить журнал, а не приговор.
GROWTH_RATIO = 3.0
GROWTH_MIN_WORKS = 500


def journal_growth(counts: list[dict], last: int | None = None) -> dict | None:
    by = {
        c.get("year"): c.get("works_count") or 0
        for c in counts
        if isinstance(c, dict) and isinstance(c.get("year"), int)
    }
    if not by:
        return None
    if last is None:
        # Последний полный год — предпоследний из известных (текущий неполный).
        years = sorted(by)
        last = years[-2] if len(years) > 1 else years[-1]
    now, before = by.get(last, 0), by.get(last - 3, 0)
    ratio = round(now / before, 2) if before > 0 else None
    return {
        "year": last,
        "works": now,
        "works_before": before,
        "ratio": ratio,
        "sharp": bool(
            now >= GROWTH_MIN_WORKS
            and (before == 0 or (ratio is not None and ratio >= GROWTH_RATIO))
        ),
    }


def crossref_journal(msg: object) -> dict:
    """Ответ api.crossref.org/works?filter=issn:<ISSN>&rows=0&facet=publisher-name:1
    → есть ли у статей с этим ISSN DOI в Crossref и кто издатель.

    Справочник /journals не годится: книжные серии и материалы конференций
    (например, AIP Conference Proceedings, 270 тыс. DOI) там отвечают 404.
    """
    m = msg.get("message") if isinstance(msg, dict) else None
    if not isinstance(m, dict):
        return {"crossref": False}
    total = m.get("total-results") or 0
    pub = ""
    facets = m.get("facets") if isinstance(m.get("facets"), dict) else {}
    vals = (facets.get("publisher-name") or {}).get("values") if facets else None
    if isinstance(vals, dict) and vals:
        pub = max(vals.items(), key=lambda kv: kv[1])[0]
    return {
        "crossref": total > 0,
        # Crossref отдаёт названия с HTML-кодами: &quot;Innovative Academy&quot;.
        "crossref_publisher": " ".join(html.unescape(str(pub)).split()),
        "crossref_dois": total,
    }


def ror_record(d: object) -> dict | None:
    """Запись ROR v2: официальные названия по языкам, статус, связи."""
    if not isinstance(d, dict):
        return None
    names: dict[str, str] = {}
    for n in d.get("names") or []:
        if not isinstance(n, dict):
            continue
        lang = n.get("lang")
        types = n.get("types") or []
        v = " ".join(str(n.get("value") or "").split())
        if lang and v and "label" in types and lang not in names:
            names[lang] = v
        if "ror_display" in types and v:
            names.setdefault("display", v)
    rel = [
        {
            "type": r.get("type") or "",
            "id": short_id(r.get("id")),
            "name": " ".join(str(r.get("label") or "").split()),
        }
        for r in d.get("relationships") or []
        if isinstance(r, dict)
    ]
    links = [
        safe_url(l.get("value"))
        for l in d.get("links") or []
        if isinstance(l, dict) and l.get("type") == "website"
    ]
    return {
        "id": short_id(d.get("id")),
        "names": names,
        "status": d.get("status") or "",
        "established": d.get("established"),
        "types": d.get("types") or [],
        "relationships": rel[:20],
        "website": next((u for u in links if u), ""),
    }


# ----------------------------------------------------------------------------
# Проверка цитирования самых цитируемых работ (самоцитирование, «картели»)
# ----------------------------------------------------------------------------

# Проверяем только работы с таким числом цитирований и больше.
CHECK_MIN_CITES = 10
# Доля цитирований выше этой — тревожный признак.
CHECK_FLAG_SHARE = 0.5


def oc_counts(rows: object) -> dict:
    """Ответ OpenCitations /citations/doi:… → сколько ссылок, сколько из них
    самоцитирование автора (author_sc) и журнала (journal_sc)."""
    lst = rows if isinstance(rows, list) else []
    n = len(lst)
    a = sum(1 for x in lst if isinstance(x, dict) and x.get("author_sc") == "yes")
    j = sum(1 for x in lst if isinstance(x, dict) and x.get("journal_sc") == "yes")
    return {"n": n, "author_sc": a, "journal_sc": j}


def citing_institutions(resp: dict, exclude: set[str]) -> dict:
    """group_by authorships.institutions.lineage по цитирующим работам →
    сколько цитирующих работ, из них своих, и самая частая чужая организация."""
    meta = resp.get("meta") if isinstance(resp, dict) else None
    total = (meta or {}).get("count") or 0
    own = 0
    top = None
    for g in group_list(resp):
        if g["id"] in exclude:
            own = max(own, g["n"])
        elif top is None:
            top = g
    return {
        "citing": total,
        "own": own,
        "own_share": share(own, total),
        "top": top,
        "top_share": share(top["n"], total) if top else None,
    }


def work_check(work: dict, oc: dict, inst: dict) -> dict:
    flags = []
    if inst["citing"] >= CHECK_MIN_CITES:
        if (inst["own_share"] or 0) > CHECK_FLAG_SHARE:
            flags.append("own_institution")
        if (inst["top_share"] or 0) > CHECK_FLAG_SHARE:
            flags.append("one_institution")
    if oc["n"] >= CHECK_MIN_CITES:
        if oc["author_sc"] / oc["n"] > CHECK_FLAG_SHARE:
            flags.append("author_self")
        if oc["journal_sc"] / oc["n"] > CHECK_FLAG_SHARE:
            flags.append("journal_self")
    loc = work.get("primary_location")
    src = loc.get("source") if isinstance(loc, dict) else None
    src = src if isinstance(src, dict) else {}
    return {
        "id": short_id(work.get("id")),
        "doi": str(work.get("doi") or "").replace("https://doi.org/", ""),
        "title": " ".join(str(work.get("display_name") or "").split())[:300],
        "year": work.get("publication_year"),
        "source": " ".join(str(src.get("display_name") or "").split()),
        "cited": work.get("cited_by_count") or 0,
        "citing": inst["citing"],
        "own": inst["own"],
        "own_share": inst["own_share"],
        "top_inst": inst["top"],
        "top_share": inst["top_share"],
        "oc": oc,
        "flags": flags,
    }


def citation_check_summary(rows: list[dict]) -> dict:
    citing = sum(r["citing"] for r in rows)
    own = sum(r["own"] for r in rows)
    ocn = sum(r["oc"]["n"] for r in rows)
    return {
        "checked": len(rows),
        "flagged": sum(1 for r in rows if r["flags"]),
        "own_share": share(own, citing),
        "author_sc_share": share(sum(r["oc"]["author_sc"] for r in rows), ocn),
        "journal_sc_share": share(sum(r["oc"]["journal_sc"] for r in rows), ocn),
        "oc_citations": ocn,
        "works": rows,
    }


def children_of(inst: dict) -> set[str]:
    return {
        short_id(a.get("id"))
        for a in inst.get("associated_institutions") or []
        if a.get("relationship") == "child"
    }


def works_in(inst: dict, first: int, last: int) -> int:
    return sum(
        c.get("works_count") or 0
        for c in inst.get("counts_by_year") or []
        if first <= (c.get("year") or 0) <= last
    )


def safe_url(v: object) -> str:
    """Только обычные ссылки http(s): в данных OpenAlex встречается мусор."""
    s = str(v or "").strip()
    return s if s.lower().startswith(("https://", "http://")) and " " not in s else ""


# --- Новые разделы (ноябрь 2026): ЦУР, языки, фонды, APC, плодовитость ---

# Порог «сверхплодовитого» автора: больше 72 статей, обзоров и докладов
# конференций за один календарный год — одна работа каждые 5 дней
# (Ioannidis, Klavans, Boyack. Nature 561, 167–169, 2018).
PROLIFIC_PER_YEAR = 72
PROLIFIC_TYPES = "article|review|conference-paper"


def sdg_block(resp: dict, with_sdg: int, total: int) -> dict:
    """Цели устойчивого развития ООН (классификатор OpenAlex).

    Одна работа может относиться к нескольким целям, поэтому доли целей
    считаются от числа работ с хотя бы одной целью ([with_sdg]).
    """
    goals = []
    for g in group_list(resp):
        if not g["id"].isdigit() or not 1 <= int(g["id"]) <= 17:
            continue
        goals.append({"id": int(g["id"]), "n": g["n"]})
    goals.sort(key=lambda g: (-g["n"], g["id"]))
    return {
        "works": with_sdg,
        "share": share(with_sdg, total),
        "goals": goals,
    }


def languages_list(resp: dict, limit: int = 10) -> list[dict]:
    """Языки публикаций: [{id: 'en', name: 'English', n}]."""
    return [
        {"id": g["id"].lower(), "name": g["name"], "n": g["n"]}
        for g in group_list(resp)
    ][:limit]


def funders_block(
    resp: dict, funded: int, total: int, info: dict[str, dict], limit: int = 15
) -> dict:
    """Фонды, указанные в работах (благодарности и метаданные издателя)."""
    top = []
    for g in group_list(resp)[:limit]:
        f = info.get(g["id"]) or {}
        top.append(
            {
                "id": g["id"],
                "name": " ".join(str(f.get("display_name") or g["name"]).split()),
                "country": f.get("country_code") or "",
                "n": g["n"],
            }
        )
    return {"works": funded, "share": share(funded, total), "top": top}


def apc_sum(pages: list[dict]) -> dict:
    """Сумма group_by=apc_paid.value_usd: Σ (цена × число работ).

    OpenAlex отдаёт оценку по прайс-листу журнала (для золотого и
    гибридного открытого доступа), а не фактический платёж.
    """
    works = 0
    usd = 0.0
    for resp in pages:
        for x in groups(resp):
            n = x.get("count")
            try:
                v = float(x.get("key"))
            except (TypeError, ValueError):
                continue
            if not isinstance(n, int) or v <= 0 or math.isnan(v):
                continue
            works += n
            usd += v * n
    return {"works": works, "usd": int(round(usd))}


def prolific_candidates(authors: dict[str, dict], first: int, last: int) -> list[str]:
    """Авторы, у которых по counts_by_year (все типы работ — оценка сверху)
    в каком-то году окна больше порога. Их проверяем точным запросом."""
    best: dict[str, int] = {}
    for aid, a in authors.items():
        for c in a.get("counts_by_year") or []:
            if not isinstance(c, dict):
                continue
            y, n = c.get("year"), c.get("works_count")
            if (
                isinstance(y, int)
                and isinstance(n, int)
                and first <= y <= last
                and n > PROLIFIC_PER_YEAR
            ):
                best[aid] = max(best.get(aid, 0), n)
    # Самые плодовитые — первыми: проверяется не больше 10.
    return sorted(best, key=lambda a: (-best[a], a))


def prolific_row(row: dict, year_counts: dict[str, int]) -> dict | None:
    """Строка автора, если в каком-то году статей, обзоров и докладов
    (по всем местам работы) больше порога; иначе None."""
    years = {
        int(k): n for k, n in year_counts.items() if k.isdigit() and isinstance(n, int)
    }
    over = {y: n for y, n in years.items() if n > PROLIFIC_PER_YEAR}
    if not over:
        return None
    top_year = max(over, key=lambda y: (over[y], y))
    return {
        **row,
        "max": over[top_year],
        "max_year": top_year,
        "years_over": len(over),
    }
