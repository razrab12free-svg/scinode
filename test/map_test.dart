import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/institution.dart';
import 'package:scinode/models/taxonomy.dart';
import 'package:scinode/screens/science_map_screen.dart';
import 'package:scinode/services/map_service.dart';
import 'package:scinode/strings.dart';

/// Реальные ответы OpenAlex (05.11.2026), test/fixtures/map.
Map<String, dynamic> _fx(String name) =>
    jsonDecode(File('test/fixtures/map/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Подменный OpenAlex: отвечает образцами и считает запросы.
class FakeOpenAlex {
  final calls = <String>[];

  Future<Map<String, dynamic>> fetch(
      String path, Map<String, String> params) async {
    calls.add('$path ${params['filter'] ?? ''} ${params['group_by'] ?? ''}');
    final f = params['filter'] ?? '';
    final g = params['group_by'] ?? '';
    if (path == '/institutions/I47151758') return _fx('institution_nuuz.json');
    if (path == '/institutions') {
      final j = _fx('institutions_uz.json');
      // Запрос по списку id — отдаём только запрошенные.
      if (f.startsWith('openalex:')) {
        final ids = f.substring('openalex:'.length).split('|').toSet();
        j['results'] = [
          for (final r in j['results'] as List)
            if (ids.contains((r['id'] as String).split('/').last)) r,
        ];
      }
      return j;
    }
    if (path == '/works' && g == 'authorships.author.id') {
      return _fx('top_authors_nuuz.json');
    }
    if (path == '/works' && f.startsWith('authorships.institutions.id:')) {
      return _fx('partners_nuuz.json');
    }
    if (path == '/works' && f.startsWith('primary_topic.')) {
      return _fx('field_activity_uz.json');
    }
    throw StateError('unexpected $path $params');
  }
}

void main() {
  group('Institution', () {
    final i = Institution.fromOpenAlex(_fx('institution_nuuz.json'));

    test('поля организации', () {
      expect(i.id, 'I47151758');
      expect(i.name, 'National University of Uzbekistan');
      expect(i.type, 'education');
      expect(i.city, 'Tashkent');
      expect(i.countryCode, 'UZ');
      expect(i.country, 'Uzbekistan');
      expect(i.lat, closeTo(41.26465, 1e-6));
      expect(i.lng, closeTo(69.21627, 1e-6));
      expect(i.works, 16966);
      expect(i.cited, 84898);
      expect(i.hIndex, 95);
      expect(i.homepage, 'https://nuu.uz/');
      expect(i.topics.length, 5);
      expect(i.topics.first, 'Linguistic research and analysis');
      expect(i.openAlexUrl, 'https://openalex.org/I47151758');
      expect(i.citedPerWork, closeTo(84898 / 16966, 1e-9));
    });

    test('опасные ссылки на сайт не принимаются', () {
      final x = Institution.fromOpenAlex({
        'id': 'https://openalex.org/I1',
        'homepage_url': 'javascript:alert(1)',
      });
      expect(x.homepage, isNull);
      expect(x.hasGeo, isFalse);
    });

    test('список организаций Узбекистана', () {
      final list = parseInstitutions(_fx('institutions_uz.json'));
      expect(list.length, 5);
      expect(list.every((e) => e.hasGeo), isTrue);
      expect(list.first.name, 'Academy of Sciences Republic of Uzbekistan');
      expect(list.first.type, 'government');
      expect(list.map((e) => e.countryCode).toSet(), {'UZ'});
    });

    test('организации без координат не попадают на карту', () {
      final list = parseInstitutions({
        'results': [
          {'id': 'https://openalex.org/I1', 'display_name': 'No geo'},
        ],
      });
      expect(list, isEmpty);
    });
  });

  group('group_by', () {
    test('ведущие авторы: имена без двойных пробелов', () {
      final g = parseGroups(_fx('top_authors_nuuz.json'));
      expect(g.first.id, 'A5114044612');
      expect(g.first.name, 'Elyor Tukhliyevich Berdimurodov');
      expect(g.first.count, 322);
    });

    test('партнёры без самой организации, по убыванию, не больше 20', () {
      final p =
          topPartners(parseGroups(_fx('partners_nuuz.json')), 'I47151758');
      expect(p.length, 20);
      expect(p.any((e) => e.id == 'I47151758'), isFalse);
      expect(p.first.name, 'Academy of Sciences Republic of Uzbekistan');
      expect(p.first.count, 955);
      for (var k = 1; k < p.length; k++) {
        expect(p[k].count <= p[k - 1].count, isTrue);
      }
    });

    test('пустые ключи пропускаются', () {
      final g = parseGroups({
        'group_by': [
          {'key': 'unknown', 'key_display_name': 'unknown', 'count': 5},
          {
            'key': 'https://openalex.org/I2',
            'key_display_name': 'B',
            'count': 3
          },
        ],
      });
      expect(g.map((e) => e.id), ['I2']);
    });
  });

  group('Масштаб меток и линий', () {
    test('логарифмический радиус', () {
      expect(markerRadius(10, 10, 100000), 6);
      expect(markerRadius(100000, 10, 100000), 22);
      final mid = markerRadius(1000, 10, 100000);
      expect(mid, greaterThan(6));
      expect(mid, lessThan(22));
      expect(markerRadius(5, 5, 5), 14);
      expect(markerRadius(1000000, 10, 100000), 22); // за пределами — край
    });

    test('толщина линии партнёрства', () {
      expect(partnerWidth(955, 955), closeTo(8, 1e-9));
      expect(partnerWidth(10, 955), lessThan(partnerWidth(500, 955)));
      expect(partnerWidth(5, 0), 1.5);
    });

    test('уровни цитируемости', () {
      expect(citedLevel(0), 0);
      expect(citedLevel(5), 1);
      expect(citedLevel(14.9), 1);
      expect(citedLevel(15), 2);
      expect(citedLevel(40), 3);
    });
  });

  group('Кэш и регионы', () {
    test('ключ кэша не зависит от порядка параметров', () {
      final a = cacheKey('/works', {'a': '1', 'b': '2'});
      final b = cacheKey('/works', {'b': '2', 'a': '1'});
      expect(a, b);
      expect(a.length, 16);
      expect(cacheKey('/works', {'a': '1'}), isNot(a));
    });

    test('континент по точке на карте', () {
      expect(continentAt(41.3, 69.2), 'asia'); // Ташкент
      expect(continentAt(48.85, 2.35), 'europe'); // Париж
      expect(continentAt(55.75, 37.6), 'europe'); // Москва
      expect(continentAt(40.7, -74), 'north_america'); // Нью-Йорк
      expect(continentAt(-23.5, -46.6), 'south_america'); // Сан-Паулу
      expect(continentAt(-33.9, 151.2), 'oceania'); // Сидней
      expect(continentAt(-1.3, 36.8), 'africa'); // Найроби
      expect(continentAt(30.0, 31.2), 'africa'); // Каир
      expect(continentAt(35.7, 139.7), 'asia'); // Токио
      expect(continentAt(28.6, 77.2), 'asia'); // Дели
      expect(continentAt(-75, 0), 'antarctica');
    });
  });

  group('MapService', () {
    test('организации загружаются один раз, потом из кэша', () async {
      final api = FakeOpenAlex();
      final s = MapService(fetch: api.fetch, cache: MemoryJsonCache());
      final a = await s.institutions(country: 'UZ');
      final b = await s.institutions(country: 'UZ');
      expect(a.length, 5);
      expect(b.length, 5);
      expect(api.calls.length, 1);
      expect(api.calls.first, contains('country_code:uz'));
      expect(api.calls.first, contains('works_count:<5000000'));
    });

    test('направление: активность по работам, своя страна, сортировка',
        () async {
      final api = FakeOpenAlex();
      final s = MapService(fetch: api.fetch, cache: MemoryJsonCache());
      final list = await s.institutions(
        country: 'UZ',
        topic: const TagRef(tag: 'f17', name: 'Computer Science'),
      );
      expect(api.calls.first, contains('primary_topic.field.id:17'));
      // В образце /institutions — 5 организаций Узбекистана; у всех есть
      // активность из group_by, и они отсортированы по ней.
      expect(list, isNotEmpty);
      expect(list.every((i) => i.activity != null), isTrue);
      for (var k = 1; k < list.length; k++) {
        expect(list[k].activity! <= list[k - 1].activity!, isTrue);
      }
    });

    test('поддисциплина использует subfield', () async {
      final api = FakeOpenAlex();
      final s = MapService(fetch: api.fetch, cache: MemoryJsonCache());
      await s.institutions(
          topic: const TagRef(tag: 's1702', name: 'Artificial Intelligence'));
      expect(api.calls.first, contains('primary_topic.subfield.id:1702'));
    });

    test('топ-10 авторов и 20 партнёров', () async {
      final api = FakeOpenAlex();
      final s = MapService(fetch: api.fetch, cache: MemoryJsonCache());
      final a = await s.topAuthors('I47151758');
      expect(a.length, 10);
      final p = await s.partners('I47151758');
      // Координаты есть только у партнёров из образца /institutions.
      expect(p, isNotEmpty);
      expect(p.every((e) => e.$1.hasGeo && e.$2 > 0), isTrue);
    });
  });

  testWidgets('экран карты: фильтры, легенда, кластер меток', (tester) async {
    Strings.instance.lang = 'ru';
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final api = FakeOpenAlex();
    final s = MapService(fetch: api.fetch, cache: MemoryJsonCache());
    await tester.pumpWidget(
        MaterialApp(home: ScienceMapScreen(service: s, showTiles: false)));
    await tester.pumpAndSettle();

    expect(find.text('Карта науки'), findsOneWidget);
    expect(find.text('Весь мир'), findsOneWidget);
    expect(find.text('Любое направление'), findsOneWidget);
    expect(find.text('Университет'), findsWidgets); // легенда
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    // Все 5 организаций из образца в Ташкенте — на карте мира это один кружок.
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.byTooltip('Скрыть легенду'));
    await tester.pumpAndSettle();
    expect(find.text('Легенда'), findsOneWidget);
  });

  testWidgets('карточка организации: авторы, ссылки, партнёры', (tester) async {
    Strings.instance.lang = 'ru';
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final api = FakeOpenAlex();
    final s = MapService(fetch: api.fetch, cache: MemoryJsonCache());
    final inst = Institution.fromOpenAlex(_fx('institution_nuuz.json'));
    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                result = await showModalBottomSheet<String>(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) =>
                      InstitutionSheet(institution: inst, service: s),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('National University of Uzbekistan'), findsOneWidget);
    expect(find.text('Университет'), findsOneWidget);
    expect(find.text('h-индекс: 95'), findsOneWidget);
    expect(find.text('Ведущие авторы за 5 лет'), findsOneWidget);
    expect(find.text('Elyor Tukhliyevich Berdimurodov'), findsOneWidget);

    await tester.ensureVisible(find.text('Сайт организации'));
    expect(find.text('Профиль в OpenAlex'), findsOneWidget);
    await tester.ensureVisible(find.text('Показать партнёров'));
    await tester.tap(find.text('Показать партнёров'));
    await tester.pumpAndSettle();
    expect(result, 'partners');
  });
}
