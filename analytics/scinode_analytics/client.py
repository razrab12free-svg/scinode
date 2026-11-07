"""Клиент OpenAlex: только стандартная библиотека Python.

Ключ берётся из переменной окружения OPENALEX_API_KEY (в репозитории его нет).
Каждый ответ можно записать на диск (record_dir) — так собираются образцы для
тестов; в тестах вместо сети используется ReplayClient.
"""

from __future__ import annotations

import hashlib
import http.client
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable

API = "https://api.openalex.org"
USER_AGENT = "scinode-analytics/1 (+https://github.com/razrab12free-svg/scinode)"


class OpenAlexError(Exception):
    pass


# Сетевые сбои, после которых запрос стоит повторить: обрыв соединения,
# недочитанный ответ (http.client.IncompleteRead), тайм-аут, битый JSON.
NETWORK_ERRORS = (
    urllib.error.URLError,
    http.client.HTTPException,
    ConnectionError,
    TimeoutError,
    OSError,
    ValueError,
)


class BudgetExhausted(OpenAlexError):
    """Дневной лимит ключа OpenAlex исчерпан: ждать часами нельзя — расчёт
    останавливается и ничего не публикует (старые данные остаются)."""


# Ждём не дольше этого; если сервер просит дольше — это исчерпанный дневной
# лимит, а не короткая перегрузка.
MAX_WAIT = 120


def _retry_after(e: urllib.error.HTTPError, attempt: int) -> float:
    wait = e.headers.get("Retry-After") if e.headers else None
    try:
        return float(wait) if wait is not None else float(2 ** attempt)
    except ValueError:
        return float(2 ** attempt)


def request_key(path: str, params: dict[str, str]) -> str:
    """Имя файла для образца ответа: не зависит от ключа и порядка параметров."""
    clean = {k: v for k, v in params.items() if k != "api_key"}
    raw = path + "?" + urllib.parse.urlencode(sorted(clean.items()))
    return hashlib.sha1(raw.encode()).hexdigest()[:16]


class OpenAlexClient:
    def __init__(
        self,
        api_key: str | None = None,
        record_dir: Path | None = None,
        retries: int = 5,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self.api_key = api_key if api_key is not None else os.environ.get(
            "OPENALEX_API_KEY", ""
        )
        self.record_dir = record_dir
        self.retries = retries
        self.sleep = sleep
        self.calls = 0
        self.ext_calls = 0  # запросы к Crossref, OpenCitations, ROR
        # Сколько запросов ключа осталось на сегодня (из заголовков OpenAlex).
        self.remaining: int | None = None

    def get(self, path: str, params: dict[str, str]) -> dict:
        q = dict(params)
        if self.api_key:
            q["api_key"] = self.api_key
        url = API + path + "?" + urllib.parse.urlencode(q)
        last: Exception | None = None
        for attempt in range(self.retries):
            try:
                req = urllib.request.Request(
                    url,
                    headers={"Accept": "application/json", "User-Agent": USER_AGENT},
                )
                with urllib.request.urlopen(req, timeout=60) as r:
                    data = json.loads(r.read().decode("utf-8"))
                    left = r.headers.get("X-RateLimit-Remaining")
                    if left is not None and str(left).isdigit():
                        self.remaining = int(left)
                self.calls += 1
                if self.record_dir is not None:
                    self.record_dir.mkdir(parents=True, exist_ok=True)
                    f = self.record_dir / f"{request_key(path, params)}.json"
                    f.write_text(
                        json.dumps(
                            {"path": path, "params": params, "response": data},
                            ensure_ascii=False,
                        ),
                        encoding="utf-8",
                    )
                return data
            except urllib.error.HTTPError as e:
                last = e
                # 429 — лимит запросов, 5xx — временный сбой: ждём и повторяем,
                # но не часами: долгое ожидание значит, что лимит дня исчерпан.
                if e.code == 429 or e.code >= 500:
                    wait = _retry_after(e, attempt)
                    if e.code == 429 and wait > MAX_WAIT:
                        raise BudgetExhausted(
                            f"лимит OpenAlex исчерпан, сброс через {int(wait)} с"
                        ) from e
                    self.sleep(min(wait, MAX_WAIT))
                    continue
                raise OpenAlexError(f"{e.code} {path}") from e
            except NETWORK_ERRORS as e:
                last = e
                self.sleep(2 ** attempt)
        raise OpenAlexError(f"{path}: {last}")

    def get_url(self, url: str) -> object | None:
        """GET к другому открытому API (Crossref, OpenCitations, ROR).

        Возвращает JSON или None, если записи нет (404). Ключ OpenAlex сюда
        не передаётся. Ответ можно записать как образец (record_dir).
        """
        last: Exception | None = None
        for attempt in range(self.retries):
            try:
                req = urllib.request.Request(
                    url,
                    headers={"Accept": "application/json", "User-Agent": USER_AGENT},
                )
                with urllib.request.urlopen(req, timeout=60) as r:
                    data = json.loads(r.read().decode("utf-8"))
                self.ext_calls += 1
                self._record_url(url, data)
                return data
            except urllib.error.HTTPError as e:
                last = e
                if e.code == 404:
                    self._record_url(url, None)
                    return None
                if e.code == 429 or e.code >= 500:
                    # Внешний сервис перегружен: подождать немного; если просит
                    # долго — пропустить проверку, а не держать весь расчёт.
                    wait = _retry_after(e, attempt)
                    if wait > MAX_WAIT:
                        raise OpenAlexError(f"{e.code} {url}: ждать {int(wait)} с") from e
                    self.sleep(wait)
                    continue
                raise OpenAlexError(f"{e.code} {url}") from e
            except NETWORK_ERRORS as e:
                last = e
                self.sleep(2 ** attempt)
        raise OpenAlexError(f"{url}: {last}")

    def _record_url(self, url: str, data: object | None) -> None:
        if self.record_dir is None:
            return
        self.record_dir.mkdir(parents=True, exist_ok=True)
        f = self.record_dir / f"url_{url_key(url)}.json"
        f.write_text(
            json.dumps({"url": url, "response": data}, ensure_ascii=False),
            encoding="utf-8",
        )


def url_key(url: str) -> str:
    return hashlib.sha1(url.encode()).hexdigest()[:16]


class ReplayClient:
    """Отвечает записанными настоящими ответами (для тестов, без сети)."""

    def __init__(self, fixtures: Path) -> None:
        self.data: dict[str, dict] = {}
        self.urls: dict[str, object] = {}
        for f in fixtures.glob("*.json"):
            j = json.loads(f.read_text(encoding="utf-8"))
            if "path" in j and "response" in j:
                self.data[request_key(j["path"], j["params"])] = j["response"]
            elif "url" in j and "response" in j:
                self.urls[url_key(j["url"])] = j["response"]
        self.calls = 0
        self.ext_calls = 0

    def get_url(self, url: str) -> object | None:
        k = url_key(url)
        if k not in self.urls:
            raise OpenAlexError(f"нет образца для {url}")
        self.ext_calls += 1
        return self.urls[k]

    def get(self, path: str, params: dict[str, str]) -> dict:
        k = request_key(path, params)
        if k not in self.data:
            raise OpenAlexError(f"нет образца для {path} {params}")
        self.calls += 1
        return self.data[k]
