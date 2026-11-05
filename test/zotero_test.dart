import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scinode/models/paper.dart';
import 'package:scinode/models/zotero.dart';
import 'package:scinode/screens/library_screen.dart';
import 'package:scinode/screens/zotero_screen.dart';
import 'package:scinode/services/library_service.dart';
import 'package:scinode/services/zotero_service.dart';
import 'package:scinode/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

dynamic fx(String name) =>
    jsonDecode(File('test/fixtures/zotero/$name').readAsStringSync());

String fxRaw(String name) =>
    File('test/fixtures/zotero/$name').readAsStringSync();

const key = 'abcdefghijklmnopqrstuvwx';

void main() {
  group('Разбор ответов Zotero', () {
    test('записи с DOI (живой ответ группы 100)', () {
      final items = parseItems(fx('items_group100.json'));
      expect(items.length, 5);
      final a = items.first;
      expect(a.key, 'XMT4Q4FT');
      expect(a.title, 'The art of doing (geographies of) music');
      expect(a.authors, ['Nichola Wood', 'Michelle Duffy', 'Susan J Smith']);
      expect(a.year, 2007);
      expect(a.venue, 'Environment and Planning D: Society and Space');
      expect(a.doi, '10.1068/d416t');
      expect(items.where((i) => i.hasDoi).length, 4);
      final p = a.toPaper(42);
      expect(p.id, 'https://www.zotero.org/users/42/items/XMT4Q4FT');
      expect(p.doi, 'https://doi.org/10.1068/d416t');
      expect(p.doiShort, '10.1068/d416t');
    });

    test('веб-страницы без DOI (живой ответ группы 1000)', () {
      final items = parseItems(fx('items_group1000_webpages.json'));
      expect(items.length, 5);
      expect(items.every((i) => i.type == 'webpage' && !i.hasDoi), isTrue);
      expect(items.first.url, startsWith('http'));
    });

    test('вложения и заметки пропускаются, DOI из поля Extra', () {
      final items = parseItems([
        {
          'key': 'A',
          'data': {'key': 'A', 'itemType': 'attachment', 'title': 'PDF'}
        },
        {
          'key': 'B',
          'data': {
            'key': 'B',
            'itemType': 'book',
            'title': 'Книга',
            'creators': [
              {'creatorType': 'author', 'name': 'ЮНЕСКО'}
            ],
            'date': 'March 2019',
            'extra': 'Тип: отчёт\nDOI: 10.5555/ABC.123',
          }
        },
      ]);
      expect(items.length, 1);
      expect(items.single.doi, '10.5555/abc.123');
      expect(items.single.authors, ['ЮНЕСКО']);
      expect(items.single.year, 2019);
    });

    test('коллекции и дерево (живой ответ группы 1002)', () {
      final cols = parseCollections(fx('collections_group1002.json'));
      expect(cols.length, 2);
      expect(cols.first.key, '6G5XQIJC');
      expect(cols.first.name, 'Articles');
      expect(cols.first.parent, isNull);
      expect(cols.first.items, 10);
      final tree = collectionTree([
        const ZoteroCollection(key: 'c', name: 'Вложенная', parent: 'a'),
        const ZoteroCollection(key: 'b', name: 'Бета'),
        const ZoteroCollection(key: 'a', name: 'Альфа'),
        const ZoteroCollection(key: 'x', name: 'Сирота', parent: 'нет'),
      ]);
      expect(tree.map((e) => '${e.$1.name}:${e.$2}'),
          ['Альфа:0', 'Вложенная:1', 'Бета:0', 'Сирота:0']);
    });

    test('сведения о ключе (форма из тестов Zotero)', () {
      final k = ZoteroKeyInfo.fromJson(fx('key_info.json'))!;
      expect(k.userId, 1);
      expect(k.username, 'Username');
      expect(k.canRead, isTrue);
      expect(k.canWrite, isTrue);
      expect(ZoteroKeyInfo.fromJson({'username': 'x'}), isNull);
      final ro = ZoteroKeyInfo.fromJson({
        'userID': 5,
        'access': {
          'user': {'library': true}
        }
      })!;
      expect(ro.canWrite, isFalse);
    });

    test('итог записи: созданные и ошибки', () {
      final r = ZoteroWriteResult.fromJson(fx('write_response.json'));
      expect(r.created, {0: 'ABC123'});
      expect(r.failed, {1: 'Note too long'});
      // Старая форма (без successful), как в pyzotero.
      final old = ZoteroWriteResult.fromJson({
        'success': {'0': 'K1', '1': 'K2'},
        'unchanged': {},
        'failed': {},
      });
      expect(old.created, {0: 'K1', 1: 'K2'});
    });

    test('normDoi', () {
      expect(normDoi('https://doi.org/10.1038/NATURE12373'),
          '10.1038/nature12373');
      expect(normDoi('http://dx.doi.org/10.1068/d416t'), '10.1068/d416t');
      expect(normDoi('doi: 10.1068/d416t '), '10.1068/d416t');
      expect(normDoi('не DOI'), isNull);
      expect(normDoi(''), isNull);
      expect(normDoi(null), isNull);
    });

    test('статья → запись Zotero: только поля из настоящего шаблона', () {
      final template = (fx('item_template_journalArticle.json') as Map).keys;
      const p = Paper(
        id: 'https://openalex.org/W1',
        title: 'Deep learning',
        year: 2015,
        authors: ['Yann LeCun', 'Yoshua Bengio', 'Platon'],
        venue: 'Nature',
        doi: 'https://doi.org/10.1038/nature14539',
        abstractText: 'Аннотация',
      );
      final z = paperToZotero(p, collection: 'COLL1');
      expect(template, containsAll(z.keys));
      expect(z['itemType'], 'journalArticle');
      expect(z['DOI'], '10.1038/nature14539');
      expect(z['date'], '2015');
      expect(z['collections'], ['COLL1']);
      expect(z['creators'], [
        {'creatorType': 'author', 'firstName': 'Yann', 'lastName': 'LeCun'},
        {'creatorType': 'author', 'firstName': 'Yoshua', 'lastName': 'Bengio'},
        {'creatorType': 'author', 'name': 'Platon'},
      ]);
      expect(paperToZotero(p)['collections'], isEmpty);
    });
  });

  group('ZoteroService', () {
    late MemoryZoteroKeyStore store;
    late List<http.Request> sent;

    ZoteroService svc(Future<http.Response> Function(http.Request r) h) {
      sent = [];
      return ZoteroService(
        client: MockClient((r) {
          sent.add(r);
          return h(r);
        }),
        store: store,
        owner: () => 'uid1',
        wait: (_) => Duration.zero,
      );
    }

    http.Response json(Object body,
            {int status = 200, Map<String, String> headers = const {}}) =>
        http.Response.bytes(utf8.encode(jsonEncode(body)), status,
            headers: {'content-type': 'application/json', ...headers});

    setUp(() => store = MemoryZoteroKeyStore());

    test('подключение: заголовки, сохранение, повторная загрузка', () async {
      final s = svc((r) async => http.Response(fxRaw('key_info.json'), 200));
      final a = await s.connect('  $key ');
      expect(a.userId, 1);
      expect(a.canWrite, isTrue);
      final r = sent.single;
      expect(r.url.toString(), 'https://api.zotero.org/keys/current');
      expect(r.headers['Zotero-API-Key'], key);
      expect(r.headers['Zotero-API-Version'], '3');
      expect(store.data.keys, ['zotero_uid1']);

      final again = ZoteroService(store: store, owner: () => 'uid1');
      await again.ensureLoaded();
      expect(again.account?.userId, 1);
      expect(again.account?.key, key);

      await s.disconnect();
      expect(store.data, isEmpty);
      expect(s.connected, isFalse);
    });

    test('неверный ключ, ключ без доступа, нет сети', () async {
      final bad = svc((r) async => http.Response('Invalid key', 403));
      await expectLater(bad.connect(key),
          throwsA(isA<ZoteroException>().having((e) => e.kind, 'kind', 'key')));
      await expectLater(bad.connect('коротко'),
          throwsA(isA<ZoteroException>().having((e) => e.kind, 'kind', 'key')));
      final noLib = svc((r) async => json({'userID': 3, 'access': {}}));
      await expectLater(
          noLib.connect(key),
          throwsA(
              isA<ZoteroException>().having((e) => e.kind, 'kind', 'access')));
      final down = svc((r) async => throw const SocketException('нет сети'));
      await expectLater(
          down.connect(key),
          throwsA(
              isA<ZoteroException>().having((e) => e.kind, 'kind', 'network')));
      expect(store.data, isEmpty);
    });

    Future<ZoteroService> connected(
        Future<http.Response> Function(http.Request r) h) async {
      final s = svc((r) {
        if (r.url.path == '/keys/current') {
          return Future.value(http.Response(fxRaw('key_info.json'), 200));
        }
        return h(r);
      });
      await s.connect(key);
      sent.clear();
      return s;
    }

    test('записи листаются страницами по 100 до Total-Results', () async {
      final one = (fx('items_group100.json') as List).first as Map;
      List<Map> page(int n, int from) => [
            for (var i = 0; i < n; i++)
              {
                ...one,
                'key': 'K${from + i}',
                'data': {...one['data'] as Map, 'key': 'K${from + i}'},
              }
          ];
      final s = await connected((r) async {
        final start = int.parse(r.url.queryParameters['start']!);
        return json(page(start == 0 ? 100 : 30, start),
            headers: {'total-results': '130'});
      });
      final items = await s.items(collection: 'COLL');
      expect(items.length, 130);
      expect(sent.length, 2);
      expect(sent.first.url.path, '/users/1/collections/COLL/items/top');
      expect(sent.first.url.queryParameters,
          {'format': 'json', 'limit': '100', 'start': '0'});
      expect(sent.last.url.queryParameters['start'], '100');
    });

    test('на 429 ждёт Retry-After и повторяет один раз', () async {
      var n = 0;
      final s = await connected((r) async {
        n++;
        return n == 1
            ? http.Response('', 429, headers: {'retry-after': '3'})
            : json(fx('collections_group1002.json'));
      });
      expect((await s.collections()).length, 2);
      expect(n, 2);
      final busy = await connected(
          (r) async => http.Response('', 429, headers: {'retry-after': '3'}));
      await expectLater(
          busy.collections(),
          throwsA(
              isA<ZoteroException>().having((e) => e.kind, 'kind', 'busy')));
    });

    test('экспорт: пропуск повторов по DOI, пакеты по 50, токен записи',
        () async {
      final posts = <http.Request>[];
      final s = await connected((r) async {
        if (r.method == 'GET') return json(fx('items_group100.json'));
        posts.add(r);
        final body = jsonDecode(r.body) as List;
        return json({
          'successful': {},
          'success': {
            for (var i = 0; i < body.length; i++) '$i': 'NEW$i',
          },
          'unchanged': {},
          'failed': {},
        });
      });
      final papers = [
        // Уже есть в Zotero (DOI из ответа группы 100, в другом регистре).
        const Paper(
            id: 'p0', title: 'Дубль', doi: 'https://doi.org/10.1068/D416T'),
        for (var i = 0; i < 60; i++)
          Paper(id: 'p${i + 1}', title: 'Статья $i', doi: '10.9999/x$i'),
        // Повтор внутри выбора.
        const Paper(id: 'p99', title: 'Повтор', doi: '10.9999/x0'),
      ];
      final r = await s.export(papers, collection: 'COLL');
      expect(r.created, 60);
      expect(r.skipped, 2);
      expect(r.failed, isEmpty);
      expect(posts.length, 2);
      expect((jsonDecode(posts[0].body) as List).length, 50);
      expect((jsonDecode(posts[1].body) as List).length, 10);
      for (final p in posts) {
        expect(p.url.toString(), 'https://api.zotero.org/users/1/items');
        expect(p.headers['Zotero-Write-Token'],
            matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(p.headers['Content-Type'], startsWith('application/json'));
      }
      expect(posts[0].headers['Zotero-Write-Token'],
          isNot(posts[1].headers['Zotero-Write-Token']));
      final first = (jsonDecode(posts[0].body) as List).first as Map;
      expect(first['collections'], ['COLL']);
      expect(first['DOI'], '10.9999/x0');
    });

    test('без права записи экспорт не отправляется', () async {
      final s = svc((r) async => json({
            'userID': 7,
            'access': {
              'user': {'library': true}
            }
          }));
      await s.connect(key);
      await expectLater(
          s.createCollection('Scinode'),
          throwsA(
              isA<ZoteroException>().having((e) => e.kind, 'kind', 'write')));
    });

    test('новая коллекция', () async {
      final s = await connected((r) async => json({
            'successful': {},
            'success': {'0': 'COLLNEW'},
            'unchanged': {},
            'failed': {},
          }));
      expect(await s.createCollection(' Scinode '), 'COLLNEW');
      final r = sent.single;
      expect(r.url.path, '/users/1/collections');
      expect(jsonDecode(r.body), [
        {'name': 'Scinode', 'parentCollection': false}
      ]);
    });
  });

  group('Экраны Zotero', () {
    setUp(() async {
      Strings.instance.lang = 'ru';
      SharedPreferences.setMockInitialValues({});
      await LibraryService.instance.ensureLoaded(force: true);
      await LibraryService.instance.clearAll();
    });

    Future<void> pump(WidgetTester tester, Widget w) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: w));
      await tester.pumpAndSettle();
    }

    testWidgets('подключение и импорт статей с DOI без дублей', (tester) async {
      final svc = ZoteroService(
        client: MockClient((r) async {
          if (r.url.path == '/keys/current') {
            return http.Response(fxRaw('key_info.json'), 200);
          }
          if (r.url.path.endsWith('/collections')) {
            return http.Response.bytes(
                utf8.encode(fxRaw('collections_group1002.json')), 200);
          }
          return http.Response.bytes(
              utf8.encode(fxRaw('items_group100.json')), 200);
        }),
        store: MemoryZoteroKeyStore(),
        owner: () => 'uid1',
      );
      await pump(tester, ZoteroScreen(service: svc));
      expect(find.text('Как подключить'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Подключить Zotero'), 300);
      await tester.enterText(find.byType(TextField), key);
      await tester.tap(find.text('Подключить Zotero'));
      await tester.pumpAndSettle();
      expect(find.text('Zotero подключён'), findsWidgets);
      expect(find.text('Чтение и запись'), findsOneWidget);

      await tester.tap(find.text('Импорт из Zotero'));
      await tester.pumpAndSettle();
      expect(
          find.text('The art of doing (geographies of) music'), findsOneWidget);
      expect(find.text('Нет DOI'), findsOneWidget);
      await tester.tap(find.text('Выбрать все (4)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Перенести в библиотеку (4)'));
      await tester.pumpAndSettle();
      expect(LibraryService.instance.items.length, 4);
      expect(find.text('Уже в библиотеке'), findsNWidgets(4));
      expect(find.text('Добавлено в библиотеку: 4'), findsOneWidget);
    });
  });

  group('Вёрстка Zotero на узком телефоне с крупным шрифтом', () {
    Future<void> pumpNarrow(WidgetTester tester, Widget home) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(1.2)),
          child: w!,
        ),
        home: home,
      ));
      await tester.pumpAndSettle();
    }

    for (final lang in ['ru', 'uz', 'en']) {
      testWidgets('подключение, разделы и шапка библиотеки ($lang)',
          (tester) async {
        Strings.instance.lang = lang;
        final store = MemoryZoteroKeyStore();
        final svc = ZoteroService(
          client: MockClient(
              (r) async => http.Response(fxRaw('key_info.json'), 200)),
          store: store,
          owner: () => 'uid1',
        );
        await pumpNarrow(tester, ZoteroScreen(service: svc));
        await svc.connect(key);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byIcon(Icons.link_off), 200);
        expect(find.byIcon(Icons.link_off), findsOneWidget);
        await pumpNarrow(tester, const Scaffold(body: LibraryScreen()));
        expect(find.byIcon(Icons.sync_alt), findsWidgets);
      });
    }
  });
}
