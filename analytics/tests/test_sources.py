"""Crossref, OpenCitations, ROR и защита дневного лимита OpenAlex.

Образцы — настоящие ответы от 5 ноября 2026 (tests/fixtures/external/).
"""

import datetime as dt
import io
import json
import urllib.error
from email.message import Message
from pathlib import Path

import pytest

from scinode_analytics import build, metrics as m
from scinode_analytics.client import (
    MAX_WAIT,
    BudgetExhausted,
    OpenAlexClient,
    OpenAlexError,
)

FX = Path(__file__).parent / "fixtures" / "external"


def fx(name):
    return json.loads((FX / name).read_text(encoding="utf-8"))


def test_opencitations_self_citation_flags():
    # Статья в Results in Physics (2023), соавтор — пед. университет им. Низами.
    oc = m.oc_counts(fx("opencitations_10.1016_j.rinp.2023.106761.json"))
    assert oc == {"n": 40, "author_sc": 1, "journal_sc": 3}
    assert m.oc_counts(None) == {"n": 0, "author_sc": 0, "journal_sc": 0}
    assert m.oc_counts([{"x": 1}, "bad"])["n"] == 2


def test_crossref_journal():
    # Серия материалов конференций: в справочнике /journals её нет (404),
    # но статей с DOI — 270 тыс. Проверяем именно статьи.
    aip = m.crossref_journal(fx("crossref_works_0094-243X.json"))
    assert aip == {"crossref": True, "crossref_publisher": "AIP Publishing",
                   "crossref_dois": 270051}
    none = m.crossref_journal(fx("crossref_works_2347-6915.json"))
    assert none["crossref"] is False and none["crossref_dois"] == 0
    assert m.crossref_journal(None) == {"crossref": False}


def test_ror_names_by_language():
    r = m.ror_record(fx("ror_011647w73.json"))
    assert r["names"]["ru"] == "Национальный университет Узбекистана"
    assert r["names"]["uz"] == "Oʻzbekiston Milliy Universiteti"
    assert r["names"]["display"] == "National University of Uzbekistan"
    assert r["status"] == "active" and r["established"] == 1918
    assert r["website"] == "https://nuu.uz/"
    assert r["relationships"][0]["type"] == "related"
    p = m.ror_record(fx("ror_051g1n833.json"))
    # Берётся официальное название (label), а не одно из старых (alias).
    assert p["names"]["ru"] == "Национальный педагогический университет Узбекистана имени Низами"
    assert p["names"]["uz"] == "Nizomiy nomidagi O'zbekiston Milliy pedagogika universiteti"
    assert p["established"] == 1935
    assert m.ror_record(None) is None


def test_journal_growth():
    counts = [
        {"year": 2026, "works_count": 900},
        {"year": 2025, "works_count": 1500},
        {"year": 2024, "works_count": 900},
        {"year": 2023, "works_count": 600},
        {"year": 2022, "works_count": 400},
    ]
    g = m.journal_growth(counts, 2025)
    assert (g["works"], g["works_before"], g["ratio"], g["sharp"]) == (1500, 400, 3.75, True)
    # Маленький журнал, вырос в 3 раза — но меньше 500 работ: не тревога.
    small = [{"year": 2025, "works_count": 90}, {"year": 2022, "works_count": 30}]
    assert m.journal_growth(small, 2025)["sharp"] is False
    assert m.journal_growth([], 2025) is None


def test_citation_check_flags():
    inst = m.citing_institutions(
        {
            "meta": {"count": 40},
            "group_by": [
                {"key": "https://openalex.org/I1", "key_display_name": "Self", "count": 25},
                {"key": "https://openalex.org/I9", "key_display_name": "Other", "count": 6},
            ],
        },
        {"I1"},
    )
    assert inst["own"] == 25 and inst["own_share"] == 0.625
    assert inst["top"]["name"] == "Other" and inst["top_share"] == 0.15
    w = m.work_check(
        {"id": "https://openalex.org/W1", "doi": "https://doi.org/10.1/x",
         "display_name": "T", "publication_year": 2023, "cited_by_count": 40,
         "primary_location": {"source": {"display_name": "J"}}},
        {"n": 40, "author_sc": 30, "journal_sc": 2},
        inst,
    )
    assert w["doi"] == "10.1/x" and w["source"] == "J"
    assert w["flags"] == ["own_institution", "author_self"]
    # Мало цитирований — не проверяем (шум).
    few = m.work_check({"id": "W2"}, {"n": 5, "author_sc": 5, "journal_sc": 5},
                       m.citing_institutions({"meta": {"count": 5}}, set()))
    assert few["flags"] == []
    s = m.citation_check_summary([w, few])
    assert s["checked"] == 2 and s["flagged"] == 1
    assert s["author_sc_share"] == round(35 / 45, 4)


def _http_error(code, retry_after=None):
    h = Message()
    if retry_after is not None:
        h["Retry-After"] = str(retry_after)
    return urllib.error.HTTPError("https://api.openalex.org/x", code, "x", h, io.BytesIO(b""))


def test_daily_limit_stops_instead_of_waiting_hours(monkeypatch):
    waits = []
    c = OpenAlexClient(api_key="k", sleep=waits.append)

    def boom(*a, **k):
        raise _http_error(429, 9421)  # настоящий ответ: сброс через 2,6 часа

    monkeypatch.setattr("urllib.request.urlopen", boom)
    with pytest.raises(BudgetExhausted):
        c.get("/works", {})
    assert waits == []  # ни секунды не ждали


def test_short_429_is_retried(monkeypatch):
    waits = []
    c = OpenAlexClient(api_key="k", sleep=waits.append, retries=3)
    monkeypatch.setattr(
        "urllib.request.urlopen", lambda *a, **k: (_ for _ in ()).throw(_http_error(429, 2))
    )
    with pytest.raises(OpenAlexError) as e:
        c.get("/works", {})
    assert not isinstance(e.value, BudgetExhausted)
    assert waits == [2.0, 2.0, 2.0] and max(waits) <= MAX_WAIT


def test_external_404_is_none(monkeypatch):
    c = OpenAlexClient(api_key="k", sleep=lambda s: None)
    monkeypatch.setattr(
        "urllib.request.urlopen", lambda *a, **k: (_ for _ in ()).throw(_http_error(404))
    )
    assert c.get_url("https://api.crossref.org/journals/0000-0000") is None


class _Low:
    """Клиент, у которого почти не осталось дневного лимита."""

    remaining = 100

    def get(self, path, params):
        return {"results": [
            {"id": f"https://openalex.org/I{i}", "type": "education",
             "counts_by_year": [{"year": 2024, "works_count": 500}]}
            for i in range(10)
        ], "meta": {"next_cursor": None}}


def test_preflight_refuses_when_budget_too_small(tmp_path):
    with pytest.raises(BudgetExhausted) as e:
        build.build_all(_Low(), tmp_path, today=dt.date(2026, 11, 5), log=lambda *_: None)
    assert "осталось 100" in str(e.value)
    # Ничего не записано — на сайте останутся прошлые данные.
    assert not (tmp_path / "analytics" / "v1" / "index.json").exists()


def test_incomplete_read_is_retried(monkeypatch):
    # Настоящий сбой при расчёте 6 ноября 2026: ответ оборвался на середине.
    import http.client

    calls = []

    class Ok:
        headers = {}

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def read(self):
            return b'{"ok": 1}'

    def flaky(*a, **k):
        calls.append(1)
        if len(calls) == 1:
            raise http.client.IncompleteRead(b"x" * 10, 5)
        return Ok()

    monkeypatch.setattr("urllib.request.urlopen", flaky)
    c = OpenAlexClient(api_key="k", sleep=lambda s: None)
    assert c.get_url("https://api.opencitations.net/x") == {"ok": 1}
    assert c.get("/works", {}) == {"ok": 1}
