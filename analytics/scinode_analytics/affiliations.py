"""«Потерянные» работы и выборочная проверка привязки (ноябрь 2026).

Сравнение строк мест работы — rapidfuzz (нечёткое сравнение, MIT).
Только чистые функции: запросы делает build.py.

- Потерянные работы: OpenAlex ищет исходные строки места работы
  (raw_affiliation_strings) по официальным названиям организации среди
  работ, которые к ней НЕ привязаны. Каждая найденная строка проверяется
  здесь: действительно ли в ней название организации, не филиал ли это и
  не другая ли организация с похожим названием («…University of
  Economics»). Итог — оценка числа потерянных работ и список для
  исправления в OpenAlex.
- Выборочная проверка: случайные работы организации; совпадает ли
  исходная строка места работы с её названием (точность привязки) и
  совпадает ли год с Crossref.
"""

from __future__ import annotations

import re
import unicodedata

from rapidfuzz import fuzz

from .metrics import share, short_id, wilson_high, wilson_low

MATCH = 90  # порог partial_ratio: название входит в строку почти дословно
LOST_SAMPLE = 100  # работ-кандидатов в одном запросе (самые цитируемые)
LOST_LIST = 20  # работ в списке для вуза
AUDIT_SAMPLE = 50  # случайных работ в выборочной проверке
AUDIT_CROSSREF = 20  # из них проверить по Crossref (с DOI)

BRANCH = re.compile(r"\b(branch|filial|filiali|филиал\w*)\b", re.I)
_APOS = str.maketrans({c: "'" for c in "‘’ʻʼ`´"})


def norm(s: object) -> str:
    """Для сравнения: нижний регистр, одинаковые апострофы, без лишних пробелов."""
    t = unicodedata.normalize("NFKC", str(s or "")).translate(_APOS).lower()
    t = re.sub(r"[\"«»“”()]", " ", t)
    return " ".join(t.split())


def name_variants(meta: dict, ror: dict | None) -> list[str]:
    """Официальные названия организации: OpenAlex + ROR (ru, uz, en).

    Сокращения (NUU) не берём: слишком много совпадений с чужими.
    """
    out: list[str] = []
    cand = [meta.get("name")] + list(meta.get("alt") or [])
    if ror:
        cand += [v for k, v in (ror.get("names") or {}).items() if k != "acronym"]
    for c in cand:
        c = " ".join(str(c or "").split())
        if len(c) >= 12 and norm(c) not in {norm(x) for x in out}:
            out.append(c)
    return out[:6]


def search_filter(variants: list[str]) -> str:
    """Значение raw_affiliation_strings.search: "A" OR "B" (без кавычек внутри)."""
    return " OR ".join('"' + v.replace('"', " ") + '"' for v in variants)


def mentions(raw: str, variants: list[str]) -> int:
    """Насколько строка содержит одно из названий (0–100)."""
    r = norm(raw)
    return int(max((fuzz.partial_ratio(norm(v), r) for v in variants), default=0))


def classify(raw: str, institutions: list[dict], variants: list[str]) -> str | None:
    """Вид совпадения строки места работы у работы, не привязанной к организации.

    None — строка не о нашей организации (или о другой с похожим названием);
    branch — филиал (OpenAlex считает его отдельной организацией);
    unlinked — организация не определена вовсе (потеряна);
    other_org — привязана к другой организации (возможная ошибка).
    """
    ours = mentions(raw, variants)
    if ours < MATCH:
        return None
    if BRANCH.search(raw):
        return "branch"
    names = [str(i.get("display_name") or "") for i in institutions if isinstance(i, dict)]
    if not names:
        return "unlinked"
    # Строка лучше подходит к той организации, к которой привязана (и её
    # название длиннее нашего: «Tashkent State University of Economics»),
    # — значит это не наша работа.
    r = norm(raw)
    for n in names:
        if len(norm(n)) > min(len(norm(v)) for v in variants) and fuzz.partial_ratio(norm(n), r) >= MATCH:
            return None
    return "other_org"


ORDER = {"unlinked": 0, "other_org": 1, "branch": 2}


def lost_works(resp: dict, variants: list[str]) -> dict:
    """Разбор ответа поиска кандидатов (самые цитируемые сначала)."""
    results = resp.get("results") if isinstance(resp, dict) else None
    results = results if isinstance(results, list) else []
    found = (resp.get("meta") or {}).get("count") if isinstance(resp, dict) else 0
    found = found if isinstance(found, int) else 0
    kinds = {"unlinked": 0, "other_org": 0, "branch": 0}
    rows = []
    for w in results:
        if not isinstance(w, dict):
            continue
        best = None
        for a in w.get("authorships") or []:
            if not isinstance(a, dict):
                continue
            for raw in a.get("raw_affiliation_strings") or []:
                k = classify(str(raw), a.get("institutions") or [], variants)
                if k and (best is None or ORDER[k] < ORDER[best[0]]):
                    names = [
                        str(i.get("display_name") or "")
                        for i in a.get("institutions") or []
                        if isinstance(i, dict)
                    ]
                    best = (k, " ".join(str(raw).split())[:300], "; ".join(names)[:200])
        if not best:
            continue
        kinds[best[0]] += 1
        if best[0] != "branch":
            rows.append(
                {
                    "id": short_id(w.get("id")),
                    "doi": str(w.get("doi") or "").replace("https://doi.org/", ""),
                    "title": " ".join(str(w.get("display_name") or "").split())[:300],
                    "year": w.get("publication_year"),
                    "cited": w.get("cited_by_count") or 0,
                    "kind": best[0],
                    "raw": best[1],
                    "assigned": best[2],
                }
            )
    checked = len(results)
    lost = kinds["unlinked"] + kinds["other_org"]
    # Оценка на все найденные работы — по доле подтверждённых в проверенных.
    estimate = round(found * lost / checked) if checked else 0
    return {
        "variants": variants,
        "found": found,
        "checked": checked,
        **kinds,
        "estimate": estimate,
        "works": rows[:LOST_LIST],
    }


def _year(item: dict) -> int | None:
    for k in ("published", "issued", "published-print", "published-online"):
        parts = ((item.get(k) or {}).get("date-parts") or [[None]])[0]
        if parts and isinstance(parts[0], int):
            return parts[0]
    return None


def audit(resp: dict, lineage: set[str], variants: list[str], crossref: dict[str, object]) -> dict:
    """Выборочная проверка случайных работ организации.

    Привязка подтверждена, если у автора из организации исходная строка
    места работы содержит её название или название подразделения, к
    которому OpenAlex привязал автора. Crossref: есть ли DOI и совпадает
    ли год (± 1 — разница между онлайн- и печатной версией).
    """
    results = resp.get("results") if isinstance(resp, dict) else None
    results = results if isinstance(results, list) else []
    with_raw = ok = 0
    for w in results:
        if not isinstance(w, dict):
            continue
        raws, names = [], []
        for a in w.get("authorships") or []:
            if not isinstance(a, dict):
                continue
            mine = [
                i for i in a.get("institutions") or []
                if isinstance(i, dict)
                and (short_id(i.get("id")) in lineage
                     or lineage & {short_id(x) for x in i.get("lineage") or []})
            ]
            if mine:
                raws += [str(r) for r in a.get("raw_affiliation_strings") or []]
                names += [str(i.get("display_name") or "") for i in mine]
        if not raws:
            continue
        with_raw += 1
        if any(mentions(r, variants + [n for n in names if len(n) >= 8]) >= MATCH for r in raws):
            ok += 1
    cr_checked = cr_found = year_ok = 0
    for w in results:
        doi = str((w or {}).get("doi") or "").replace("https://doi.org/", "")
        if not doi or doi not in crossref:
            continue
        cr_checked += 1
        item = crossref[doi]
        msg = item.get("message") if isinstance(item, dict) else None
        if not isinstance(msg, dict):
            continue
        cr_found += 1
        y = _year(msg)
        if y is not None and isinstance(w.get("publication_year"), int) and abs(y - w["publication_year"]) <= 1:
            year_ok += 1
    return {
        "sample": len(results),
        "attr_checked": with_raw,
        "attr_ok": ok,
        "attr_share": share(ok, with_raw),
        "attr_ci": [wilson_low(ok, with_raw), wilson_high(ok, with_raw)] if with_raw else None,
        "crossref_checked": cr_checked,
        "crossref_found": cr_found,
        "year_ok": year_ok,
        "year_share": share(year_ok, cr_found),
    }
