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


def test_fwci_stats_median_not_mean():
    s = m.fwci_stats([0, 0, 0.5, 1.2, 40.0, None], sampled=False, total=6)
    assert s["n"] == 5
    assert s["median"] == 0.5  # одна «звёздная» статья не тянет медиану
    assert s["mean"] == 8.34
    assert s["above1"] == 0.4
    assert m.fwci_stats([], True, 0)["median"] is None


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
    assert c["fwci"]["n"] == 93 and not c["fwci"]["sampled"]
    assert c["fwci"]["median"] == 0.0
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


def test_national_report_uses_sample(built):
    _, base, _ = built
    d = json.loads((base / "orgs" / "UZ.json").read_text(encoding="utf-8"))
    f = d["citation"]["fwci"]
    assert f["sampled"] and f["n"] > 4000 and f["total"] > 100000
    assert d["works"] > 100000
    assert d["org"]["type"] == "country"


def test_replay_unknown_request_fails():
    with pytest.raises(OpenAlexError):
        ReplayClient(FX).get("/works", {"filter": "nothing"})


def test_main_without_key(monkeypatch, capsys):
    monkeypatch.delenv("OPENALEX_API_KEY", raising=False)
    assert build.main(["--out", "/nonexistent"]) == 2
    assert "OPENALEX_API_KEY" in capsys.readouterr().err
