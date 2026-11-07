# Scinode — инструкции для Claude

## Общение с владельцем
- Общаться **только на русском**, простыми словами. Владелец работает с телефона,
  без компьютера и опыта программирования.
- Если есть выбор, который меняет результат, — сначала спросить, а не угадывать.

## О проекте
Scinode — мобильное приложение для коллаборации учёных. Flutter/Dart, Android
(позже iOS через PWA). Package name / applicationId: `app.scinode.scinode`.

Уже сделано:
- вход через Google (Firebase Auth);
- 3 языка интерфейса: русский, узбекский (латиница), английский;
- поиск статей OpenAlex, библиотека, скачивание PDF через Unpaywall, читалка (pdfrx);
- профиль учёного (Firestore, коллекция `profiles`);
- раздел «Гранты»: открытые конкурсы (EU Funding & Tenders, Grants.gov) и
  профинансированные проекты (NIH RePORTER, NSF).
- дерево направлений OpenAlex, поиск учёных по теме, имени и среди участников.

## Архитектура (`lib/`)
- `main.dart` — запуск, Firebase, тема, язык.
- `firebase_config.dart` — публичные ключи Firebase (публичны по замыслу,
  данные защищают правила Firestore).
- `auth_service.dart` — вход через Google.
- `theme.dart` — Material 3, светлая и тёмная темы.
- `utils.dart` — общие помощники.
- `strings.dart`, `strings_extra.dart`, `strings_pdf.dart`, `strings_science.dart` —
  все тексты интерфейса. Функция `t('ключ', {'n': 5})`.
- `screens/` — экраны (`home_shell.dart` — главная с плитками и нижней навигацией,
  `search_screen`, `library_screen`, `network_screen`, `profile_screen`,
  `profile_edit_screen`, `pdf_reader_screen`, `paper_sheet`, `login_screen`).
- `services/` — работа с сетью и хранилищем (`openalex_service`, `scientist_service`,
  `taxonomy_service`, `profile_service`, `library_service`, `pdf_store`,
  `grants_service` — 4 источника грантов, каждый грузится независимо;
  `map_service` — карта науки; `reading_progress` — прогресс чтения PDF;
  `chat_service` — чат; `board_service` — канбан-доски; `report_pdf` — PDF-отчёт
  по доске; `motivation_service` — серия дней и недельная цель, на телефоне;
  `zotero_service` — Zotero Web API v3, ключ в flutter_secure_storage;
  `note_service` — заметки с формулами; `app_lock_service` — замок приложения
  через local_auth, настройка только на телефоне; `orcid_service` — заполнение
  профиля по ORCID; `analytics_service` — отчёты Аналитики с GitHub Pages, кэш 24 ч).
- `models/` — модели данных и разбор JSON (`paper`, `scientist`, `profile`, `taxonomy`,
  `grant` — конкурсы, проекты, даты, суммы; `board`, `board_report` — доски и
  статистика отчёта).
- `widgets/` — переиспользуемые виджеты (`paper_card`, `scientist_card`,
  `taxonomy_picker`, `logo`, `math_markdown` — Markdown + формулы LaTeX через
  flutter_markdown_plus и flutter_math_fork, `math_toolbar` — кнопки формул).
- `test/` — юнит-тесты; `test/fixtures/` — реальные образцы ответов API.
- `tools/make_icon.py` — рисует иконку приложения в CI.
- `assets/fonts/` — шрифт Noto Sans (OFL) для PDF-отчётов: без встроенного шрифта
  кириллица и узбекские буквы в PDF превращаются в квадратики.

## Заметки по API грантов
- EU (SEDIA): `POST https://api.tech.ec.europa.eu/search-api/prod/rest/search?apiKey=SEDIA`,
  multipart-поля `query`, `sort`, `languages`, `displayFields` — **обязательно** с
  `Content-Type: application/json`. Типы 1, 2, 8 (0 — закупки), статусы 31094501
  (скоро) и 31094502 (открыт). Дата в фильтре только в виде `2026-11-05T00:00:00.000+0000`.
  Без `sort` страницы идут с повторами. У многоэтапных конкурсов несколько
  `deadlineDate` — ближайший будущий вычисляем сами.
- Grants.gov: `search2` (posted/forecasted), подробности — `fetchOpportunity`.
  Страницы — `startRecordNum` (с 0) и `rows`; всего — `data.hitCount`. Проверено:
  страницы по 100 при сортировке `closeDate|asc` идут без повторов и пропусков.
  Обязательная фраза-дисклеймер — строка `gr.disclaimer`.
- NIH: `POST /v2/projects/search`, `advanced_text_search` с operator `and`.
- NSF: `GET /services/v1/awards.json`; слова в `keyword` соединять через `AND`.

## Заметки по ORCID
- `GET https://pub.orcid.org/v3.0/<id>/person` и `/employments`, заголовок
  `Accept: application/json`, без ключа (полная `/record` весит до 0,5 МБ — не брать).
  Нет записи — 404. Автор OpenAlex — `/authors/orcid:<id>` (404, если нет).
- Номер проверяется по контрольной цифре (ISO 7064 MOD 11-2), `normalizeOrcid`
  понимает ссылку orcid.org и ввод без дефисов. Образцы — `test/fixtures/orcid/`.
- Значка «подтверждено» нет: вход через ORCID (OAuth) требует сервера (Blaze).

## Заметки по Zotero
- `https://api.zotero.org`, заголовки `Zotero-API-Key` и `Zotero-API-Version: 3`.
  Сведения о ключе — `GET /keys/current` (`userID`, `username`, `access.user.library/write`).
- Списки — `format=json&limit=100&start=N`, заголовок `Total-Results`. Запись —
  `POST /users/<id>/items` (до 50 за раз) с `Zotero-Write-Token` (32 hex); ответ —
  `success`/`successful`/`unchanged`/`failed`. На 429/503 ждать `Retry-After`/`Backoff`.
- Сайт www.zotero.org из облачной среды закрыт; формы ответов без ключа сверены с
  кодом Zotero и pyzotero (см. `test/fixtures/zotero/README.md`).

## Формулы
- Формулы: `$…$`, `\(…\)` в строке; `$$…$$`, `\[…\]` блоком. `$5 и $10` — не формула
  (после открывающего `$` нет пробела, перед закрывающим — пробела, кроме как после
  команды, после закрывающего — цифры). Правила в `math_markdown.dart` и
  `models/note.dart` должны совпадать (есть тест).
- Выгрузка заметок — `services/note_export.dart`: PDF (формулы рисуются в PNG через
  пакет screenshot), .tex (pdfLaTeX: inputenc utf8, fontenc T2A,T1, babel), .md.
  Разбор Markdown для выгрузки — с `encodeHtml: false`, иначе «&» станет «&amp;».
- Шаблоны формул — `models/formula_templates.dart`, названия — строки `ft.<ключ>`.

## Заметки по OpenAlex и карте
- Без ключа все пользователи с одного IP делят $0.10/день; с бесплатным ключом —
  $1/день, запрос стоит около $0.0001. Ключ берётся из переменной окружения
  `OPENALEX_API_KEY` (в коде и в репозитории его быть не должно).
- Дерево направлений встроено: `assets/taxonomy/openalex_v2.json` (официальный список
  тем OpenAlex v2 из github.com/ourresearch/openalex-topic-classification), переводы
  разделов и синонимы — `lib/strings_subfields.dart`, поиск — `searchTaxonomy`.
- `/institutions` не фильтруется по координатам: только `country_code`, `continent`,
  `type`, `topics.field.id`. Активность по направлению — `works` с
  `group_by=authorships.institutions.id`. Ответы кэшируются на телефоне на 24 часа.
- Тайлы OpenStreetMap: обязательны подпись «© OpenStreetMap contributors» и
  `userAgentPackageName: app.scinode.scinode`.

## Firestore
- Коллекции: `profiles/{uid}`, `conversations/{uid1_uid2}` (+ `messages`), `reports`,
  `boards/{id}` (+ `cards` → `comments`, `activity`), `notes/{id}` (поле `o` —
  владелец, видит только он). Роли досок: владелец (поле `ow`),
  редактор, наблюдатель. Порядок карточек — дробное поле `o` (см. `models/board.dart`).
  Время фокуса — поле карточки `ft` (uid → секунды); каждый прибавляет только своё.
- Записи в Firestore не ждать в интерфейсе (`fireAndReport`): без сети они
  сохраняются локально и завершаются позже.
- Правила — файл `firestore.rules` в корне (источник правды). После изменения:
  прогнать тесты эмулятора (`firestore_tests/`, нужны Node и Java) и прислать
  владельцу ПОЛНЫЙ текст файла для вставки в консоль Firebase.
- Для тестов Dart-кода с Firestore — `fake_cloud_firestore`.

## Замок приложения
- `local_auth` требует `FlutterFragmentActivity` и тему AppCompat — это делает шаг
  «App lock» в `build.yml` (sed по MainActivity и styles.xml + зависимость appcompat).
- Экран замка — поверх всего в `MaterialApp.builder` (`main.dart`), экраны под ним
  не пересоздаются. Уход в окно PIN во время проверки не считается выходом.

## Scinode Аналитика (`analytics/`)
- Python: стандартная библиотека + пакеты из `analytics/requirements.txt` с точными версиями
  (разрешены владельцем 6.11.2026: rapidfuzz, pandas, numpy; новые — только с согласия).
  Workflow `.github/workflows/analytics.yml`:
  тесты на PR; расчёт и публикация на GitHub Pages — 3-го числа каждого месяца, при
  push в main с изменениями `analytics/` и вручную. Секрет `OPENALEX_API_KEY`.
- Данные: `https://razrab12free-svg.github.io/scinode/analytics/v1/index.json` и
  `orgs/<id>.json` (`UZ.json` — вся страна). Методика и формат — `analytics/README.md`.
- Тесты: `cd analytics && python -m pytest -q tests` — на записанных настоящих ответах
  (`--record` записывает новые образцы; ключ в них не попадает).
- Главный показатель уровня — **собственные работы** (`corresponding_institution_ids`):
  PP(top 10%) по всем работам завышает «гостевое» соавторство. «Сильные» направления —
  только по собственным работам и с интервалом Уилсона (`metrics.wilson_low`).
- Добавлять поля в JSON можно без смены схемы; менять/удалять — только с новой схемой.
- Дневной лимит OpenAlex — $1 (≈ 10 000 запросов) **на аккаунт, не на ключ**: второй ключ
  того же аккаунта лимит не добавляет; можно докупить по $1. Сброс 00:00 UTC (05:00 Ташкент).
  Новые настройки среды (ключ, адреса) видны только в новой сессии. Полный расчёт ≈ 6 500. При 429 с
  долгим `Retry-After` клиент бросает `BudgetExhausted` (не ждёт часами), расчёт ничего
  не публикует. Перед стартом — проверка остатка. Не гонять полные расчёты локально тем
  же ключом в день запуска на GitHub.
- Внешние источники: OpenCitations (самоцитирование), Crossref (журналы), ROR (названия) —
  через `client.get_url`; образцы — `analytics/tests/fixtures/external/`. SCImago и списки
  Scopus НЕ подключать (запрет Elsevier на коммерческое использование).
- Менять формат JSON — только с повышением `SCHEMA` и папки `v<N>` (в приложении —
  `analyticsSchema` в `models/analytics.dart`; более новая схема → «обновите Scinode»).
- В приложении: плитка «Аналитика» на Главной → `screens/analytics_screen.dart`
  (список, отчёт из 8 разделов, сравнение двух организаций и со страной), диаграммы —
  `widgets/analytics_charts.dart`. Образцы — `test/fixtures/analytics/` (настоящий расчёт).
- Числа и проценты — с неразрывным пробелом (`formatMoney`, `formatShare`).
- PDF Аналитики — `services/analytics_pdf.dart` (`buildOrgPdf`, `buildComparePdf`), стиль и
  шрифты — из `report_pdf.dart`. Проверка глазами: `SCINODE_PDF_OUT=<папка> flutter test
  test/analytics_pdf_test.dart`, затем `pdftoppm -png`. В `pw.Stack` не класть пустой
  непозиционированный `SizedBox` — он обнуляет размер и полоска не рисуется.

- Архитектура и план точности — `docs/analytics_architecture.md`; открытые источники
  и лицензии — `docs/open_data_sources.md`. Исправление привязки в OpenAlex — только
  для платных участников, остальным — заявка openalex.org/contact; иерархия и переводы
  названий — в ROR (бесплатно). Спорные строки не «приписывать» вузу автоматически.

## Ссылки
- Любые ссылки из внешних данных открывать только через `openLink` (`utils.dart`):
  он пропускает лишь http(s) с адресом сайта (`isSafeWebUrl`).

## Сборка (GitHub Actions, `.github/workflows/build.yml`)
- Папка `android/` **не хранится** в репозитории: генерируется в CI командой
  `flutter create`, затем правится шагами `sed` (разрешения, название, minSdk 23).
- Порядок: pub get → dart format (проверка) → flutter analyze → flutter test →
  иконка → сборка APK → подпись → артефакт.
- **Pull Request в main**: проверки + сборка APK, APK доступен как артефакт
  `scinode-apk` на странице запуска. Release **не публикуется**.
- **Push в main** (и ручной запуск): то же + подпись постоянным ключом
  (`signing/release.jks.enc`, секрет `KEYSTORE_PASSPHRASE`) + публикация в Releases.

## Жёсткие правила
1. Никогда не пушить напрямую в main. Каждая задача — отдельная ветка и Pull Request
   с понятным описанием на русском.
2. Не трогать `signing/`, workflow `create-signing-key.yml`, секреты и логику подписи
   в `build.yml`. Не менять package name `app.scinode.scinode` и applicationId.
3. Не добавлять в репозиторий папку `android/`. Правки Android-настроек — шагом в
   `build.yml` (как для minSdk и разрешений).
4. Любой текст интерфейса — сразу на трёх языках через систему строк
   (`lib/strings*.dart`, порядок: **русский, узбекский латиницей, английский**).
   Никаких захардкоженных строк в виджетах.
5. Внешние API (OpenAlex, Unpaywall, Grants.gov, NIH RePORTER, NSF,
   EU Funding & Tenders) перед написанием кода проверять реальными запросами через
   curl и опираться на фактические ответы. Никаких выдуманных или демо-данных.
6. Перед каждым PR обязательно: `flutter pub get`, `dart format lib test`,
   `flutter analyze` без замечаний, `flutter test`. Писать юнит-тесты для разбора
   данных (парсинг JSON, даты, форматирование), лучше на реальных образцах ответов.
7. Безопасность: никаких секретов в коде. Ключи в `firebase_config.dart` публичны по
   замыслу. Если меняется структура Firestore — прислать владельцу в отчёте готовый
   текст правил для вставки в консоль Firebase.
8. Стиль: Material 3; нижние панели через `showModalBottomSheet` с безопасными
   отступами снизу; крупные кнопки (не меньше 48 px); поддержка тёмной темы;
   понятные сообщения об ошибках на трёх языках.
9. Если `flutter` не найден: `export PATH="$HOME/flutter/bin:$PATH"`. Если Flutter не
   установлен: `git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"`.
   Если сетевой адрес заблокирован — сообщить владельцу точный адрес, чтобы он добавил
   его в настройки среды.

## Порядок работы над задачей
1. Создать ветку от свежего main.
2. Для внешних API — сначала curl, сохранить образцы ответов в `test/fixtures/`.
3. Написать код (модели → сервисы → экраны), строки на трёх языках.
4. `flutter pub get && dart format lib test && flutter analyze && flutter test`.
5. Коммит, push, Pull Request на русском. Дождаться зелёной проверки в Actions.
6. Отчёт владельцу:
   1) что сделано;
   2) ссылка на PR;
   3) прошли ли проверки в Actions;
   4) что проверить на телефоне по шагам (где скачать APK, куда нажать);
   5) что сделать вручную (например, правила Firestore), если нужно.
