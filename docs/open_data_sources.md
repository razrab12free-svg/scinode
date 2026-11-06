# Открытые источники научных данных для Scinode

Только бесплатные источники с открытыми условиями. Перед подключением любого
источника: живой запрос `curl`, образец ответа в `analytics/tests/fixtures/external/`,
проверка лицензии (можно ли использовать в платном продукте). Статус «✅ открыт» —
адрес уже есть в среде `scinode`; «➕ добавить» — нужно вписать в Allowed domains
(см. `docs/network_allowlist.txt`); «⛔ не использовать» — запрет лицензии.

## Основные (уже используются)
| Источник | Адрес API | Что даёт | Лицензия | Статус |
|---|---|---|---|---|
| OpenAlex | api.openalex.org | работы, авторы, организации, журналы, темы, цитирование, ЦУР, фонды, APC, строки мест работы (`/raw-affiliation-strings`) | CC0 | ✅ |
| Справка OpenAlex | help.openalex.org (страницы `.md`) | правила API, лимиты, исправление ошибок привязки | — | ✅ |
| Crossref | api.crossref.org | DOI, журналы по ISSN, издатели, годы | метаданные открыты | ✅ |
| ROR | api.ror.org | реестр организаций: названия на языках, иерархия, `?affiliation=` — готовое сопоставление строки места работы с организацией | CC0 | ✅ |
| OpenCitations | api.opencitations.net | цитирования, отметки самоцитирования автора/журнала | CC0 | ✅ |
| ORCID | pub.orcid.org | профиль учёного, места работы | CC0 (публичные данные) | ✅ |
| Unpaywall | api.unpaywall.org | открытые версии статей | CC0 | ✅ |
| DOAJ | doaj.org/api | каталог проверенных журналов открытого доступа | CC0 (метаданные) | ✅ |
| DataCite | api.datacite.org | DOI наборов данных и программ (Zenodo и др.) | CC0 | ✅ |
| Europe PMC | www.ebi.ac.uk/europepmc | биомедицина, полные тексты | открыто | ✅ |
| PubMed | eutils.ncbi.nlm.nih.gov | биомедицина | общественное достояние | ✅ |
| arXiv, DBLP | export.arxiv.org, dblp.org | препринты, информатика | открыто / CC0 | ✅ |
| Semantic Scholar | api.semanticscholar.org | граф цитирования (без ключа — низкий лимит) | ODC-BY | ✅ |
| CORE | api.core.ac.uk | полные тексты из репозиториев (нужен бесплатный ключ) | открыто | ✅ |

## Стоит добавить (бесплатно, проверить условия перед кодом)
| Источник | Адрес | Зачем | Статус |
|---|---|---|---|
| Лейденский рейтинг Open Edition (CWTS) | zenodo.org, open.leidenranking.com | эталон методики: сверить наши PP(top 10%) | ➕ |
| OpenAIRE Graph | api.openaire.eu | проекты и гранты ЕС, связь работ с проектами | ➕ |
| Retraction Watch (через Crossref) | api.labs.crossref.org | полный список отзывов статей (CSV) | ➕ |
| OpenAPC | github.com/OpenAPC (raw.githubusercontent.com) | реально уплаченные APC (для сверки нашей оценки) | ✅ (GitHub открыт) |
| Wikidata | query.wikidata.org, www.wikidata.org | названия организаций и журналов на узбекском, связи | ➕ |
| ISSN Portal (ROAD) | portal.issn.org | проверка ISSN журналов | ➕ |
| NIH iCite | icite.od.nih.gov | RCR — нормированная цитируемость биомедицины | ➕ |
| ВАК (ОАК) Узбекистана | oak.uz (проверить адрес) | перечень признанных журналов — главный национальный стандарт | ➕ проверить |
| Платформа журналов Узбекистана | uzjournals.edu.uz (проверить) | местные журналы, которых нет в OpenAlex | ➕ проверить |

## Не использовать
| Источник | Почему |
|---|---|
| SCImago (SJR, квартили), списки Scopus | Elsevier запрещает коммерческое использование без письменного разрешения |
| Google Scholar | нет API, автоматический сбор запрещён правилами |
| Web of Science, Scopus, Dimensions API | платные, закрытые лицензии |

## Готовые решения (бесплатные, открытый код)
| Инструмент | Для чего | Где |
|---|---|---|
| rapidfuzz | нечёткое сравнение строк (названия организаций) | PyPI, MIT |
| pandas, numpy, scipy | таблицы, статистика, интервалы (бутстреп) | PyPI |
| networkx | сети соавторства | PyPI |
| pyalex | клиент OpenAlex (для разовых исследований; в расчёте — свой клиент) | PyPI |
| OpenAlex affiliation matcher | как OpenAlex сам сопоставляет строки — методика и тестовые наборы | github.com/ourresearch/openalex-affiliation-matcher |
| ROR affiliation matching | `api.ror.org/v2/organizations?affiliation=<строка>` — независимая вторая проверка | ROR |
| VOSviewer (CWTS) | карты соавторства и тем (программа для компьютера) | vosviewer.com |
| bibliometrix / openalexR | библиометрия на R (для сверки методики) | CRAN |

## Лимиты
- OpenAlex: **$1 в день на аккаунт** (не на ключ!), ≈ 10 000 запросов; сброс 00:00 UTC
  (05:00 Ташкент). Без ключа — общий $0,10 на IP. Можно докупать по $1 (pay as you go).
- Crossref: вежливо, без ключа; при нагрузке — пауза по `Retry-After`.
- ROR, OpenCitations: без ключа, умеренная частота.
