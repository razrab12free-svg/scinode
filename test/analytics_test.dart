import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scinode/models/analytics.dart';
import 'package:scinode/screens/analytics_screen.dart';
import 'package:scinode/services/analytics_service.dart';
import 'package:scinode/services/map_service.dart' show MemoryJsonCache;
import 'package:scinode/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Настоящие файлы расчёта analytics/ (5 ноября 2026): 6 крупнейших
// организаций Узбекистана, отчёты НУУз, ТГЭУ и всей страны.
String _fx(String name) =>
    File('test/fixtures/analytics/$name').readAsStringSync();
Map<String, dynamic> _j(String name) =>
    jsonDecode(_fx(name)) as Map<String, dynamic>;

const nuu = 'I47151758';

/// Неразрывный пробел в числах и процентах.
const _nb = '\u00a0';
const tsue = 'I55383850';

http.Client _pages({List<String>? sent, int status = 200}) =>
    MockClient((r) async {
      sent?.add(r.url.path);
      if (status != 200) return http.Response('x', status);
      final p = r.url.path.split('/analytics/v1/').last;
      final f = File('test/fixtures/analytics/$p');
      if (!f.existsSync()) return http.Response('not found', 404);
      return http.Response.bytes(utf8.encode(f.readAsStringSync()), 200,
          headers: {'content-type': 'application/json'});
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Разбор отчётов', () {
    test('список организаций', () {
      final i = AnalyticsIndex.fromJson(_j('index.json'));
      expect(i.schema, 1);
      expect(i.generated, DateTime(2026, 11, 5));
      expect((i.windowFrom, i.windowTo), (2021, 2025));
      expect((i.yearsFrom, i.yearsTo), (2016, 2026));
      expect(i.country, 'UZ');
      expect(i.national, isTrue);
      expect(i.orgs.length, 6);
      final o = i.orgs.first;
      expect(o.id, nuu);
      expect(o.acronyms, ['NUU']);
      expect(o.city, 'Tashkent');
      expect(o.h, 95);
    });

    test('названия на языке интерфейса из других названий OpenAlex', () {
      final o = AnalyticsIndex.fromJson(_j('index.json')).orgs.first;
      expect(o.localName('ru'), 'Национальный университет Узбекистана');
      expect(o.localName('uz'), 'Oʻzbekiston Milliy Universiteti');
      expect(o.localName('en'), 'National University of Uzbekistan');
    });

    test('поиск: сокращение, русское и узбекское название, апострофы', () {
      final orgs = AnalyticsIndex.fromJson(_j('index.json')).orgs;
      List<String> f(String q) => [
            for (final o in orgs)
              if (o.matches(q)) o.id
          ];
      expect(f('nuu'), [nuu]);
      expect(f('национальный'), [nuu]);
      expect(f("o'zbekiston milliy"), [nuu]);
      expect(f('ozbekiston'), contains(nuu));
      expect(f('economics tashkent'), [tsue]);
      expect(f(''), hasLength(6));
      expect(f('zzzz'), isEmpty);
    });

    test('отчёт НУУз: все разделы', () {
      final r = OrgReport.fromJson(_j('orgs/$nuu.json'));
      expect(r.org.name, 'National University of Uzbekistan');
      expect(r.works, 9059);
      expect(r.years.first.year, 2016);
      expect(r.years.last.year, 2026);
      for (final y in r.years) {
        expect(y.article + y.conference + y.other, y.all);
      }
      expect(r.oaWindow, 7356);
      expect(formatShare(r.oaShare, 'ru'), '81$_nb%');
      final c = r.citation;
      expect((c.top10, c.known, c.ppTop10), (795, 8860, 0.0897));
      expect(c.ppTop1, 0.0085);
      expect((c.fwciKnown, c.cited, c.above1), (8859, 2744, 1504));
      expect(c.above1Share, 0.1698);
      expect(r.intlShare, 0.1938);
      expect(r.countries.every((x) => x.id != 'UZ'), isTrue);
      expect(r.partners.every((p) => p.id != nuu), isTrue);
      expect(r.authors, isNotEmpty);
      expect(r.journals, isNotEmpty);
      expect(r.doajShare, 0.1079);
      expect(
          r.strongTopics.map((t) => t.name), contains('Applied Mathematics'));
      expect(r.types.first.id, 'article');
    });

    test('отчёт по стране', () {
      final r = OrgReport.fromJson(_j('orgs/UZ.json'));
      expect(r.org.isCountry, isTrue);
      expect(r.works, 181345);
      expect(r.citation.ppTop10, 0.0594);
    });

    test('пустой и странный JSON не ломает разбор', () {
      final r = OrgReport.fromJson({'years': 'x', 'citation': 5});
      expect(r.works, 0);
      expect(r.years, isEmpty);
      expect(r.citation.ppTop10, isNull);
      expect(r.oaShare, isNull);
      expect(AnalyticsIndex.fromJson({}).orgs, isEmpty);
    });

    test('проценты', () {
      expect(formatShare(0.0594, 'ru'), '5,9$_nb%');
      expect(formatShare(0.0594, 'en'), '5.9%');
      expect(formatShare(0.1938, 'uz'), '19$_nb%');
      expect(formatShare(0, 'en'), '0%');
      expect(formatShare(null, 'ru'), '—');
    });
  });

  group('AnalyticsService', () {
    test('адрес GitHub Pages и кэш', () async {
      final sent = <String>[];
      final cache = MemoryJsonCache();
      final s = AnalyticsService(client: _pages(sent: sent), cache: cache);
      expect(AnalyticsService.defaultBase,
          'https://x9096730-spec.github.io/scinode/analytics/v1');
      final i = await s.index();
      expect(i.orgs.length, 6);
      final r = await s.report(nuu);
      expect(r.works, 9059);
      expect(sent, [
        '/scinode/analytics/v1/index.json',
        '/scinode/analytics/v1/orgs/$nuu.json',
      ]);
      // Второй сервис с тем же кэшем в сеть не ходит.
      final s2 = AnalyticsService(client: _pages(sent: sent), cache: cache);
      await s2.report(nuu);
      expect(sent.length, 2);
    });

    test('ошибки: не опубликовано, нет сети, новая схема, чужой id', () async {
      Future<String> kind(Future<Object?> Function() f) async {
        try {
          await f();
          return 'ok';
        } on AnalyticsException catch (e) {
          return e.kind;
        }
      }

      final a = AnalyticsService(
          client: _pages(status: 404), cache: MemoryJsonCache());
      expect(await kind(a.index), 'notready');
      final b = AnalyticsService(
          client: MockClient((_) async => throw const SocketException('x')),
          cache: MemoryJsonCache());
      expect(await kind(b.index), 'network');
      final c = AnalyticsService(
          client: MockClient((_) async =>
              http.Response(jsonEncode({'schema': 2, 'orgs': []}), 200)),
          cache: MemoryJsonCache());
      expect(await kind(c.index), 'update');
      final d = AnalyticsService(client: _pages(), cache: MemoryJsonCache());
      expect(await kind(() => d.report('../x')), 'other');
      expect(await kind(() => d.report('I1')), 'notready');
    });
  });

  group('Экраны', () {
    Future<void> pump(WidgetTester tester, Widget home,
        {String lang = 'ru',
        Size size = const Size(360, 720),
        ThemeMode mode = ThemeMode.light}) async {
      await Strings.instance.setLang(lang);
      AnalyticsService.instance =
          AnalyticsService(client: _pages(), cache: MemoryJsonCache());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        themeMode: mode,
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.2)),
          child: child!,
        ),
        home: home,
      ));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
    }

    testWidgets('список: поиск и переход к отчёту', (tester) async {
      await pump(tester, const AnalyticsScreen());
      expect(find.text(t('an.title')), findsOneWidget);
      expect(find.byKey(const Key('an.country')), findsOneWidget);
      expect(find.text('Национальный университет Узбекистана (NUU)'),
          findsOneWidget);
      expect(find.text(t('an.count', {'n': 6})), findsOneWidget);

      await tester.enterText(find.byKey(const Key('an.search')), 'Samarkand');
      await tester.pump();
      expect(find.text(t('an.count', {'n': 1})), findsOneWidget);
      expect(find.byKey(const Key('an.country')), findsNothing);
      await tester.enterText(find.byKey(const Key('an.search')), 'qwerty');
      await tester.pump();
      expect(find.text(t('an.none')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('an.search')), 'NUU');
      await tester.pump();
      await tester.tap(find.textContaining('(NUU)'));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('an.compare_btn')), findsOneWidget);
      expect(find.text('Национальный университет Узбекистана'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('нет данных — понятная ошибка и «Повторить»', (tester) async {
      await Strings.instance.setLang('ru');
      AnalyticsService.instance = AnalyticsService(
          client: _pages(status: 404), cache: MemoryJsonCache());
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text(t('an.err.notready')), findsOneWidget);
      expect(find.text(t('search.retry')), findsOneWidget);
    });

    for (final lang in ['ru', 'uz', 'en']) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('отчёт НУУз: 8 разделов, узкий телефон ($lang, $mode)',
            (tester) async {
          await pump(tester, const OrgReportScreen(id: nuu),
              lang: lang, size: const Size(320, 640), mode: mode);
          expect(tester.takeException(), isNull);
          final list = find.byType(Scrollable).first;
          for (final k in [
            'an.s.years',
            'an.s.oa',
            'an.s.cite',
            'an.s.topics',
            'an.s.partners',
            'an.s.authors',
            'an.s.journals',
            'an.s.compare',
            'an.s.method',
          ]) {
            await tester.scrollUntilVisible(find.text(t(k)), 300,
                scrollable: list);
            expect(find.text(t(k)), findsWidgets, reason: k);
            expect(tester.takeException(), isNull, reason: k);
          }
        });
      }
    }

    testWidgets('столбик года показывает числа, сравнение со страной',
        (tester) async {
      await pump(tester, const OrgReportScreen(id: nuu));
      await tester.scrollUntilVisible(
          find.byKey(const Key('an.year_total')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(t('an.year_total', {'year': 2025, 'n': '2${_nb}620'})),
          findsOneWidget);
      final label = find.descendant(
          of: find.byKey(const Key('an.bar.2023')), matching: find.text("'23"));
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pump();
      expect(find.text(t('an.year_total', {'year': 2023, 'n': '2${_nb}060'})),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text(t('an.c.top10')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('9,0$_nb%'), findsOneWidget);
      expect(find.textContaining(t('an.country_v', {'v': '5,9$_nb%'})),
          findsOneWidget);
    });

    testWidgets('сравнение двух организаций', (tester) async {
      await pump(tester, const OrgReportScreen(id: nuu));
      await tester.tap(find.byKey(const Key('an.compare_btn')));
      await tester.pumpAndSettle();
      expect(find.text(t('an.compare_pick')), findsOneWidget);
      await tester.tap(find.textContaining('экономический').last);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text(t('an.s.compare')), findsOneWidget);
      expect(find.text('9${_nb}059'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text(t('an.cmp.years')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  });
}
