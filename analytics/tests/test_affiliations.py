"""«Потерянные» работы: разбор /raw-affiliation-strings на настоящих ответах.

Образцы — tests/fixtures/raw_affiliations/ (записаны 7 ноября 2026, без ключа):
строки мест работы, НЕ привязанные к организации (unmatched-institutions),
по 1–3 официальным названиям; names — названия привязанных организаций.
"""

import json
from pathlib import Path

from scinode_analytics import affiliations as A

FX = Path(__file__).parent / "fixtures" / "raw_affiliations"


def run(org):
    d = json.loads((FX / f"{org}.json").read_text(encoding="utf-8"))
    v = A.name_variants(d["meta"], d["ror"])
    return v, A.lost_strings(d["pages"], v, d["names"])


def test_nuu_branch_and_russian_strings():
    v, r = run("I47151758")
    assert v == [
        "National University of Uzbekistan",
        "Oʻzbekiston Milliy Universiteti",
        "Национальный университет Узбекистана",
    ]
    # Джизакский филиал — отдельная организация в OpenAlex (не в lineage НУУз).
    assert r["branch"] == {"strings": 100, "works": 939}
    # Строки на русском без организации — настоящие «потерянные».
    assert r["unlinked"] == {"strings": 5, "works": 10}
    first = r["top"][0]
    assert first["kind"] == "unlinked" and first["raw"].startswith("Национальный университет Узбекистана")


def test_tsue_uzbek_strings_and_samarkand_branch():
    _, r = run("I55383850")
    assert r["unlinked"] == {"strings": 10, "works": 14}
    assert r["branch"] == {"strings": 155, "works": 342}
    assert r["other_org"]["strings"] == 0


def test_well_matched_university_has_nothing_lost():
    # Все 589 строк с названием пед. университета им. Низами уже привязаны.
    _, r = run("I4210159566")
    assert r["checked"] == 0 and r["top"] == []


def test_foreign_namesake_is_not_ours():
    # «Istanbul New Century University» (Турция) — не Yangi Asr (New Century University).
    _, r = run("I4405284798")
    assert r["other_org"]["strings"] == 0
    assert all("Istanbul" not in x["raw"] for x in r["top"])


def test_classify_rules():
    v = ["Tashkent State University"]
    # Другая организация с более длинным названием — не наша.
    econ = [{"display_name": "Tashkent State University of Economics"}]
    assert A.classify("Tashkent State University of Economics, Tashkent", econ, v) is None
    assert A.classify("Tashkent State University, Tashkent", [], v) == "unlinked"
    assert A.classify("Samarkand branch of Tashkent State University", [], v) == "branch"
    assert A.classify("Tashkent State University", [], v, ["TR"]) is None
    assert A.classify("Moscow State University", [], v) is None
    assert A.norm("O‘zbekiston  «Milliy»") == "o'zbekiston milliy"
