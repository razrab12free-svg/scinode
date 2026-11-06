"""Тесты расчёта на настоящих ответах OpenAlex (записаны 5 ноября 2026)."""

import datetime as dt
import json
from pathlib import Path

import pytest

from scinode_analytics import build, metrics as m
from scinode_analytics.client import OpenAlexError, ReplayClient, request_key

FX = Path(__file__).parent / "fixtures" / "openalex"
TODAY = dt.date(2026, 11, 5)
ORG = "I4405284798"  # Yangi Asr Universiteti (Ташкент), небольшой вуз


def test_window_last_five_full_years():
    assert build.window(TODAY) == (2021, 2025)
    assert build.window(dt.date(2027, 1, 1)) == (2022, 2026)


def test_short_id():
    assert m.short_id("https://openalex.org/I47151758") == "I47151758"
    assert m.short_id("https://openalex.org/countries/UZ") == "UZ"
    assert m.short_id("https://openalex.org/subfields/3304") == "3304"
    assert m.short_id(None) == ""


def test_request_key_ignores_api_key_and_order():
    a = request_key("/works", {"filter": "x", "group_by": "y"})
    b = request_key("/works", {"group_by": "y", "filter": "x", "api_key": "secret"})
    assert a == b


def test_group_parsing():
    resp = {
        "group_by": [
            {"key": "https://openalex.org/countries/US", "key_display_name": "United  States", "count": 2},
            {"key": "unknown", "key_display_name": "unknown", "count": 9},
            {"key": "https://openalex.org/countries/GR", "key_display_name": "Greece", "count": 5},
        ]
    }
    assert m.group_list(resp) == [
        {"id": "GR", "name": "Greece", "n": 5},
        {"id": "US", "name": "United States", "n": 2},
    ]
    assert m.bool_counts({"group_by": [{"key": "true", "count": 3}, {"key": "false", "count": 7}]}) == (3, 10)
    assert m.group_list({}) == [] and m.group_list({"group_by": "x"}) == []


def test_fwci_shares():
    s = m.fwci_shares(known=200, cited=50, above1=20)
    assert s["cited_share"] == 0.25 and s["above1_share"] == 0.1
    assert m.fwci_shares(0, 0, 0)["cited_share"] is None


def test_topics_strong_needs_enough_works():
    rows = m.topics_table(
        {"a": 100, "b": 10},
        {"a": 20, "b": 5},
        {"a": 78, "b": 5},
        {"a": "A", "b": "B"},
    )
    assert rows[0]["id"] == "a" and rows[0]["pp_top10"] == 0.2041 and rows[0]["strong"]
    # 50 % в топ-10 %, но всего 10 работ — не «сильное».
    assert rows[1]["pp_top10"] == 0.5 and not rows[1]["strong"]


def test_wilson_lower_bound():
    assert m.wilson_low(0, 0) is None
    assert m.wilson_low(0, 50) == 0.0
    # 5 из 30 (17 %) — нижняя граница ниже 10 %: не «сильное».
    assert m.wilson_low(5, 30) < 0.10
    # 47 из 191 (25 %) — нижняя граница выше 10 %.
    assert m.wilson_low(47, 191) > 0.18


def test_strong_topic_counts_only_leading_works():
    # Настоящий случай (пед. университет им. Низами, 2021–2025): по
    # «биомедицинской инженерии» 192 работы, 53 в топ-10 %, но ведущих
    # работ (автор для переписки из вуза) всего 7 и ни одной в топ-10 %.
    rows = m.topics_table(
        {"2204": 192, "1213": 99},
        {"2204": 53, "1213": 17},
        {"2204": 134, "1213": 82},
        {"2204": "Biomedical Engineering", "1213": "Visual Arts"},
        lead={"2204": 7, "1213": 81},
        lead_top10={"2204": 0, "1213": 17},
        lead_no_top10={"2204": 7, "1213": 64},
    )
    bme = next(r for r in rows if r["id"] == "2204")
    arts = next(r for r in rows if r["id"] == "1213")
    assert bme["pp_top10"] == 0.2834 and not bme["strong"]
    assert bme["lead_share"] == 0.0365
    assert arts["lead_pp_top10"] == 0.2099 and arts["strong"]


def test_safe_url_and_encoded_keys():
    assert m.safe_url("https://nuu.uz/") == "https://nuu.uz/"
    assert m.safe_url("javascript:alert(1)") == ""
    assert m.safe_url("nuu.uz") == ""
    assert m.safe_url(None) == ""
    assert m.short_id("https://openalex.org/source-types/ebook%20platform") == "ebook platform"


def test_partners_exclude_self_and_children():
    lineage = [
        {"id": "I1", "name": "Self", "n": 90},
        {"id": "I2", "name": "Child", "n": 50},
        {"id": "I3", "name": "x", "n": 10},
    ]
    out = m.partner_orgs(lineage, {"I1", "I2"}, {"I3": {"name": "Other", "country": "DE", "type": "education"}})
    assert out == [{"id": "I3", "name": "Other", "country": "DE", "type": "education", "n": 10}]


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    out = tmp_path_factory.mktemp("site")
    client = ReplayClient(FX)
    idx = build.build_all(client, out, "UZ", 100, TODAY, only=[ORG], workers=1, log=lambda *_: None)
    base = out / "analytics" / "v1"
    return idx, base, client


def test_index(built):
    idx, base, _ = built
    assert idx["schema"] == 1
    assert idx["window"] == [2021, 2025] and idx["years"] == [2016, 2026]
    assert idx["national"] is True and idx["failed"] == []
    assert [o["id"] for o in idx["orgs"]] == [ORG]
    o = idx["orgs"][0]
    assert o["name"] == "Yangi Asr Universiteti"
    assert "New Century University" in o["alt"]
    assert o["city"] == "Tashkent" and o["ror"] == "0477p5695"
    assert o["works_window"] >= 100
    assert json.loads((base / "index.json").read_text(encoding="utf-8")) == idx


def test_org_report(built):
    _, base, _ = built
    d = json.loads((base / "orgs" / f"{ORG}.json").read_text(encoding="utf-8"))
    years = {r["y"]: r for r in d["years"]}
    assert set(years) == set(range(2016, 2027))
    for r in d["years"]:
        assert r["article"] + r["conference"] + r["other"] == r["all"]
        assert r["oa"] <= r["all"]
    assert sum(years[y]["all"] for y in range(2021, 2026)) == d["works"] == 93
    c = d["citation"]
    assert c["known"] == 93 and c["top10"] == 2 and c["pp_top10"] == 0.0215
    f = c["fwci"]
    assert (f["known"], f["cited"], f["above1"]) == (93, 5, 2)
    assert f["above1_share"] == 0.0215
    # Своя страна не считается партнёром, сама организация — тоже.
    assert all(x["id"] != "UZ" for x in d["collab"]["countries"])
    assert all(x["id"] != ORG for x in d["collab"]["partners"])
    assert d["collab"]["partners"][0]["name"] == "New Uzbekistan University"
    assert 0 <= d["collab"]["intl_share"] <= 1
    assert d["authors"] and all(a["n"] > 0 for a in d["authors"])
    j = d["journals"]
    assert j["top"][0]["name"].startswith("Zenodo") and j["top"][0]["type"] == "repository"
    assert 0 <= j["doaj_share"] <= 1
    assert d["topics"][0]["name"] == "Education"
    t0 = d["topics"][0]
    assert t0["lead"] == 24 and t0["lead_known"] == 24 and not t0["strong"]
    lead = c["lead"]
    assert (lead["works"], lead["top10"], lead["pp_top10"]) == (77, 2, 0.026)
    assert lead["share"] == 0.828
    assert c["mega"] == {"works": 0, "known": 0, "top10": 0, "pp_top10_without": 0.0215}
    assert d["integrity"]["retracted"] == 0
    # Проверка цитирования: у небольшого вуза нет работ от 10 цитирований.
    assert d["citation_check"]["checked"] == 0
    assert d["org"]["ror_data"]["established"] == 2021
    assert d["org"]["ror_data"]["names"]["uz"] == "Yangi Asr Universiteti"
    growth = {x["name"][:20]: x["growth"] for x in j["top"]}
    assert all(g is None or g["year"] == 2025 for g in growth.values())
    assert any(x.get("crossref") is False for x in j["top"])
    assert [x["id"] for x in d["integrity"]["source_types"]][:2] == ["journal", "repository"]


def test_national_report(built):
    _, base, client = built
    d = json.loads((base / "orgs" / "UZ.json").read_text(encoding="utf-8"))
    assert d["org"]["type"] == "country"
    assert d["works"] == 181345
    f = d["citation"]["fwci"]
    assert f["known"] > 170000 and 0 < f["above1"] < f["cited"] < f["known"]
    assert d["citation"]["pp_top10"] == 0.0594
    # Для страны «ведущих» работ нет: фильтра corresponding по стране в OpenAlex нет.
    assert "lead" not in d["citation"]
    assert d["integrity"]["retracted"] > 0
    assert all(not t.get("lead") for t in d["topics"])
    # Весь расчёт (список, вуз, страна) — 92 запроса OpenAlex (без скачивания
    # списков работ) и 31 бесплатный запрос к Crossref, OpenCitations и ROR
    # (из них 13 — «нет такого журнала» в Crossref);
    # ещё один запрос — проверка остатка лимита в main().
    assert client.calls == 92
    assert client.ext_calls == 31


def test_new_sections_org(built):
    _, base, _ = built
    d = json.loads((base / "orgs" / f"{ORG}.json").read_text(encoding="utf-8"))
    sdg = d["sdg"]
    # Записано 6.11.2026: 65 из 93 работ отнесены хотя бы к одной цели.
    assert (sdg["works"], sdg["share"]) == (65, 0.6989)
    assert sdg["goals"][0] == {"id": 4, "n": 50}  # качественное образование
    assert all(1 <= g["id"] <= 17 for g in sdg["goals"])
    assert [x["id"] for x in d["languages"]] == ["en", "uz", "ru"]
    assert sum(x["n"] for x in d["languages"]) <= d["works"]
    assert d["funding"] == {"works": 0, "share": 0.0, "top": []}
    assert d["apc"] == {"works": 0, "usd": 0, "lead": {"works": 0, "usd": 0}}
    assert d["prolific"] == {"threshold": 72, "checked": 20, "authors": []}


def test_new_sections_country(built):
    _, base, _ = built
    d = json.loads((base / "orgs" / "UZ.json").read_text(encoding="utf-8"))
    assert d["sdg"]["works"] == 106333 and d["sdg"]["share"] == 0.5864
    assert len(d["sdg"]["goals"]) == 17
    assert [x["id"] for x in d["languages"][:3]] == ["en", "uz", "ru"]
    f = d["funding"]
    assert f["works"] == 5259 and f["share"] == 0.029
    assert f["top"][0]["name"] == "National Natural Science Foundation of China"
    assert f["top"][0]["country"] == "CN"
    assert any(x["country"] == "UZ" for x in f["top"])
    # APC по стране: 4 страницы group_by (cursor), оценка по прайс-листам.
    assert d["apc"] == {"works": 3748, "usd": 7296240}
    assert "lead" not in d["apc"]
    p = d["prolific"]
    assert p["threshold"] == 72 and p["checked"] == 20
    assert p["authors"] and all(a["max"] > 72 for a in p["authors"])
    assert [a["max"] for a in p["authors"]] == sorted(
        (a["max"] for a in p["authors"]), reverse=True
    )
    # Без мегаколлабораций физики ЦЕРН в списке нет.
    assert "A5000028915" not in {a["id"] for a in p["authors"]}


def test_sdg_and_languages_parsing():
    r = {"group_by": [
        {"key": "https://openalex.org/sdgs/4", "key_display_name": "Quality education", "count": 5},
        {"key": "https://openalex.org/sdgs/18", "count": 9},
        {"key": "unknown", "count": 3},
        {"key": "https://openalex.org/sdgs/3", "count": 5},
    ]}
    assert m.sdg_block(r, 8, 10) == {
        "works": 8, "share": 0.8, "goals": [{"id": 3, "n": 5}, {"id": 4, "n": 5}]
    }
    assert m.sdg_block({}, 0, 0)["goals"] == []
    lang = {"group_by": [
        {"key": "https://openalex.org/languages/UZ", "key_display_name": "Uzbek", "count": 2},
        {"key": "https://openalex.org/languages/en", "key_display_name": "English", "count": 7},
    ]}
    assert m.languages_list(lang) == [
        {"id": "en", "name": "English", "n": 7}, {"id": "uz", "name": "Uzbek", "n": 2}
    ]


def test_apc_sum():
    pages = [
        {"group_by": [{"key": "500.0", "count": 3}, {"key": "1885.5", "count": 2}]},
        {"group_by": [{"key": "unknown", "count": 9}, {"key": "0", "count": 4},
                      {"key": "nan", "count": 1}, {"key": "100", "count": "x"}]},
    ]
    assert m.apc_sum(pages) == {"works": 5, "usd": 5271}
    assert m.apc_sum([]) == {"works": 0, "usd": 0}


def test_prolific_rules():
    authors = {
        "A1": {"counts_by_year": [{"year": 2024, "works_count": 73}]},
        "A2": {"counts_by_year": [{"year": 2024, "works_count": 72}]},
        "A3": {"counts_by_year": [{"year": 2019, "works_count": 300}]},  # вне окна
        "A4": {"counts_by_year": [{"year": 2022, "works_count": 200}, "bad"]},
    }
    assert m.prolific_candidates(authors, 2021, 2025) == ["A4", "A1"]
    row = {"id": "A1", "name": "X"}
    assert m.prolific_row(row, {"2023": 72, "2024": 80}) == {
        "id": "A1", "name": "X", "max": 80, "max_year": 2024, "years_over": 1
    }
    # Ровно 72 — ещё не «сверхплодовитый» (порог — больше 72).
    assert m.prolific_row(row, {"2023": 72}) is None
    assert m.prolific_row(row, {}) is None


def test_funders_block():
    r = {"group_by": [
        {"key": "https://openalex.org/F1", "key_display_name": "Fund  One", "count": 4},
        {"key": "https://openalex.org/F2", "key_display_name": "Two", "count": 2},
    ]}
    out = m.funders_block(r, 5, 50, {"F1": {"display_name": "Fund One", "country_code": "UZ"}})
    assert out == {"works": 5, "share": 0.1, "top": [
        {"id": "F1", "name": "Fund One", "country": "UZ", "n": 4},
        {"id": "F2", "name": "Two", "country": "", "n": 2},
    ]}


def test_replay_unknown_request_fails():
    with pytest.raises(OpenAlexError):
        ReplayClient(FX).get("/works", {"filter": "nothing"})


def test_main_without_key(monkeypatch, capsys):
    monkeypatch.delenv("OPENALEX_API_KEY", raising=False)
    assert build.main(["--out", "/nonexistent"]) == 2
    assert "OPENALEX_API_KEY" in capsys.readouterr().err
