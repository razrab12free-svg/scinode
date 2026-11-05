"""Клиент OpenAlex: только стандартная библиотека Python.

Ключ берётся из переменной окружения OPENALEX_API_KEY (в репозитории его нет).
Каждый ответ можно записать на диск (record_dir) — так собираются образцы для
тестов; в тестах вместо сети используется ReplayClient.
"""

from __future__ import annotations

import hashlib
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable

API = "https://api.openalex.org"
USER_AGENT = "scinode-analytics/1 (+https://github.com/x9096730-spec/scinode)"


class OpenAlexError(Exception):
    pass


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
                # 429 — лимит запросов, 5xx — временный сбой: ждём и повторяем.
                if e.code == 429 or e.code >= 500:
                    wait = e.headers.get("Retry-After")
                    self.sleep(float(wait) if wait and wait.isdigit() else 2 ** attempt)
                    continue
                raise OpenAlexError(f"{e.code} {path}") from e
            except (urllib.error.URLError, TimeoutError, ValueError) as e:
                last = e
                self.sleep(2 ** attempt)
        raise OpenAlexError(f"{path}: {last}")


class ReplayClient:
    """Отвечает записанными настоящими ответами (для тестов, без сети)."""

    def __init__(self, fixtures: Path) -> None:
        self.data: dict[str, dict] = {}
        for f in fixtures.glob("*.json"):
            j = json.loads(f.read_text(encoding="utf-8"))
            if "path" in j and "response" in j:
                self.data[request_key(j["path"], j["params"])] = j["response"]
        self.calls = 0

    def get(self, path: str, params: dict[str, str]) -> dict:
        k = request_key(path, params)
        if k not in self.data:
            raise OpenAlexError(f"нет образца для {path} {params}")
        self.calls += 1
        return self.data[k]
