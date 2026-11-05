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


def journal_row(s: dict, n: int) -> dict:
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
