# Образцы ответов Zotero Web API v3

Живые ответы api.zotero.org (5 ноября 2026, публичные группы, без ключа):
- `items_group100.json` — `GET /groups/100/items/top?limit=5&format=json` (журнальные статьи с DOI);
- `items_group1000_webpages.json` — `GET /groups/1000/items/top?limit=5&format=json` (веб-страницы без DOI);
- `collections_group1002.json` — `GET /groups/1002/collections?limit=5&format=json`;
- `item_template_journalArticle.json` — `GET /items/new?itemType=journalArticle`.

Без личного ключа живые ответы на эти запросы получить нельзя, поэтому формы взяты
из тестов официальных клиентов:
- `key_info.json` — `GET /keys/current`: ответ из тестов Zotero
  (github.com/zotero/zotero, test/tests/syncRunnerTest.js, «fullAccess»);
- `write_response.json` — `POST /users/<id>/items`: поля `successful`, `success`,
  `unchanged`, `failed` (`code`, `message`) как в тех же тестах Zotero и в
  pyzotero (tests/api_responses/creation_doc.json).
