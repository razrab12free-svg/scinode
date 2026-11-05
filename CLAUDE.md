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
  `map_service` — карта науки; `reading_progress` — прогресс чтения PDF).
- `models/` — модели данных и разбор JSON (`paper`, `scientist`, `profile`, `taxonomy`,
  `grant` — конкурсы, проекты, даты, суммы).
- `widgets/` — переиспользуемые виджеты (`paper_card`, `scientist_card`,
  `taxonomy_picker`, `logo`).
- `test/` — юнит-тесты; `test/fixtures/` — реальные образцы ответов API.
- `tools/make_icon.py` — рисует иконку приложения в CI.

## Заметки по API грантов
- EU (SEDIA): `POST https://api.tech.ec.europa.eu/search-api/prod/rest/search?apiKey=SEDIA`,
  multipart-поля `query`, `sort`, `languages`, `displayFields` — **обязательно** с
  `Content-Type: application/json`. Типы 1, 2, 8 (0 — закупки), статусы 31094501
  (скоро) и 31094502 (открыт). Дата в фильтре только в виде `2026-11-05T00:00:00.000+0000`.
  Без `sort` страницы идут с повторами. У многоэтапных конкурсов несколько
  `deadlineDate` — ближайший будущий вычисляем сами.
- Grants.gov: `search2` (posted/forecasted), подробности — `fetchOpportunity`.
  Обязательная фраза-дисклеймер — строка `gr.disclaimer`.
- NIH: `POST /v2/projects/search`, `advanced_text_search` с operator `and`.
- NSF: `GET /services/v1/awards.json`; слова в `keyword` соединять через `AND`.

## Заметки по OpenAlex и карте
- Без ключа все пользователи с одного IP делят $0.10/день; с бесплатным ключом —
  $1/день, запрос стоит около $0.0001. Ключ берётся из переменной окружения
  `OPENALEX_API_KEY` (в коде и в репозитории его быть не должно).
- `/institutions` не фильтруется по координатам: только `country_code`, `continent`,
  `type`, `topics.field.id`. Активность по направлению — `works` с
  `group_by=authorships.institutions.id`. Ответы кэшируются на телефоне на 24 часа.
- Тайлы OpenStreetMap: обязательны подпись «© OpenStreetMap contributors» и
  `userAgentPackageName: app.scinode.scinode`.

## Firestore
- Коллекции: `profiles/{uid}`, `conversations/{uid1_uid2}` (+ `messages`), `reports`.
- Правила — файл `firestore.rules` в корне (источник правды). После изменения:
  прогнать тесты эмулятора (`firestore_tests/`, нужны Node и Java) и прислать
  владельцу ПОЛНЫЙ текст файла для вставки в консоль Firebase.
- Для тестов Dart-кода с Firestore — `fake_cloud_firestore`.

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
