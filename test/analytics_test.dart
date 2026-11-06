import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scinode/models/analytics.dart';
import 'package:scinode/models/grant.dart' show formatMoney;
import 'package:scinode/screens/analytics_screen.dart';
import 'package:scinode/services/analytics_service.dart';
import 'package:scinode/services/map_service.dart' show MemoryJsonCache;
import 'package:scinode/strings.dart';
import 'package:scinode/utils.dart';
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
      expect(i.orgs.length, 8);
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
      expect(f('национальный педагогический'), ['I4210159566']);
      expect(f('национальный'), containsAll([nuu, 'I4210159566']));
      expect(f("o'zbekiston milliy"), contains(nuu));
      expect(f('ozbekiston'), contains(nuu));
      expect(f('economics tashkent'), [tsue]);
      expect(f(''), hasLength(8));
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

    test('русское название — не узбекская кириллица', () {
      final b = AnalyticsIndex.fromJson(_j('index.json'))
          .orgs
          .firstWhere((o) => o.id == 'I4210098011');
      expect(b.localName('ru'),
          'Бухарский государственный медицинский институт имени Абу Али ибн Сино');
      expect(b.localName('uz'),
          'Abu Ali ibn Sino nomidagi Buxoro davlat tibbiyot instituti');
    });

    test('пед. университет: «сильные» — только по собственным работам', () {
      final r = OrgReport.fromJson(_j('orgs/I4210159566.json'));
      final lead = r.citation.lead!;
      expect(r.citation.ppTop10, 0.0884);
      expect(lead.ppTop10, 0.0346); // собственные работы — в 2,5 раза ниже
      expect(lead.works, 2941);
      final bme = r.topics.firstWhere((x) => x.id == '2204');
      expect(bme.name, 'Biomedical Engineering');
      expect(bme.ppTop10, greaterThan(0.25)); // за счёт чужих статей
      expect(bme.lead, 7);
      expect(bme.strong, isFalse);
      expect(bme.mostlyGuest, isTrue);
      expect(r.strongTopics.map((x) => x.name),
          ['Visual Arts and Performing Arts']);
      expect(r.integrity.retracted, 34);
      expect(r.integrity.repository, 438);
    });

    test('проверка цитирования, журналов и ROR (настоящий расчёт)', () {
      final r = OrgReport.fromJson(_j('orgs/I4210159566.json'));
      final c = r.citationCheck!;
      expect(c.checked, 10);
      expect(c.flagged, 0);
      expect(c.authorScShare, 0.0031); // самоцитирование авторов — 0,3 %
      expect(c.ocCitations, 976);
      expect(c.works.first.cited, greaterThan(300));
      expect(c.works.first.source, 'RSC Advances');
      // Журналы без DOI в Crossref — повод проверить.
      final galaxy = r.journals
          .firstWhere((j) => j.name.startsWith('Galaxy International'));
      expect(galaxy.crossref, isFalse);
      expect(galaxy.warning, isTrue);
      // Репозиторий с ростом — не журнал, не помечается.
      final zen = r.journals.firstWhere((j) => j.type == 'repository');
      expect(zen.warning, isFalse);
      // Официальное название и год основания — из ROR.
      expect(r.org.localName('ru'),
          'Национальный педагогический университет Узбекистана имени Низами');
      expect(r.org.established, 1935);
      // У страны проверки цитирования нет.
      expect(OrgReport.fromJson(_j('orgs/UZ.json')).citationCheck, isNull);
    });

    test('институт ядерной физики: мегаколлаборации', () {
      final r = OrgReport.fromJson(_j('orgs/I4210099818.json'));
      expect(r.citation.megaWorks, 125);
      expect(r.citation.megaTop10, 43);
      expect(r.citation.ppTop10WithoutMega, 0.0909);
    });

    test('отчёт по стране', () {
      final r = OrgReport.fromJson(_j('orgs/UZ.json'));
      expect(r.org.isCountry, isTrue);
      expect(r.citation.lead, isNull);
      expect(r.integrity.retracted, greaterThan(600));
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

    test('ЦУР, языки, фонды, APC и сверхплодовитые авторы', () {
      // Настоящий расчёт 6 ноября 2026 (OpenAlex).
      final r = OrgReport.fromJson(_j('orgs/$nuu.json'));
      expect(r.sdg!.share, 0.3946);
      expect(r.sdg!.goals.every((g) => g.$1 >= 1 && g.$1 <= 17), isTrue);
      expect(r.sdg!.goals.first.$1, 4); // качественное образование
      expect(r.languages.map((l) => l.id).take(3), ['en', 'uz', 'ru']);
      expect(languageShare(r, 'uz')!, closeTo(1027 / 9059, 0.001));
      expect(r.funding!.share, 0.0899);
      expect(r.funding!.top.first.country, 'UZ');
      expect((r.apc!.works, r.apc!.usd), (466, 873698));
      expect((r.apc!.lead!.works, r.apc!.lead!.usd), (192, 305462));
      expect(r.prolific!.threshold, 72);
      expect(r.prolific!.checked, 20);
      expect(r.prolific!.authors.single.max, 91);
      expect(r.prolific!.authors.single.home, isTrue);

      final ped = OrgReport.fromJson(_j('orgs/I4210159566.json'));
      expect(ped.prolific!.authors.length, 8);
      // Почти все — зарубежные соавторы.
      expect(ped.prolific!.home, 1);
      final maxes = [for (final a in ped.prolific!.authors) a.max];
      expect(maxes, [...maxes]..sort((a, b) => b.compareTo(a)));
      // Своих работ с APC мало: почти всё платили соавторы.
      expect(ped.apc!.lead!.works, lessThan(ped.apc!.works ~/ 10));

      final uz = OrgReport.fromJson(_j('orgs/UZ.json'));
      expect(uz.apc!.lead, isNull);
      expect(uz.sdg!.goals.length, 17);

      // Старый файл без новых разделов читается без ошибок.
      final old = OrgReport.fromJson({'works': 5});
      expect(old.sdg, isNull);
      expect(old.languages, isEmpty);
      expect(old.funding, isNull);
      expect(old.apc, isNull);
      expect(old.prolific, isNull);
      expect(languageShare(old, 'uz'), isNull);
      expect(
          SdgBlock.fromJson({
            'goals': [
              {'id': 18, 'n': 3},
              'x'
            ]
          })!
              .goals,
          isEmpty);
    });

    test('качество данных и история', () {
      final r = OrgReport.fromJson(_j('orgs/$nuu.json'));
      final q = r.quality!;
      expect(q.level, 'good');
      expect(q.reasons, isEmpty);
      expect(q.doiShare, 0.8621);
      expect(q.ciLow! < r.citation.lead!.ppTop10!, isTrue);
      expect(q.ciHigh! > r.citation.lead!.ppTop10!, isTrue);
      expect(r.history.single.date, DateTime(2026, 11, 5));
      expect(r.history.single.works, r.works);
      expect(r.history.single.leadPpTop10, r.citation.lead!.ppTop10);
      final uz = OrgReport.fromJson(_j('orgs/UZ.json'));
      expect(uz.quality!.level, 'medium');
      expect(uz.quality!.reasons, ['doi_mid', 'orcid_low']);
      // Старый файл и неизвестный уровень — без раздела, без ошибок.
      expect(OrgReport.fromJson({}).quality, isNull);
      expect(OrgReport.fromJson({}).history, isEmpty);
      expect(DataQuality.fromJson({'level': 'excellent'}), isNull);
      final h = HistoryPoint.list([
        {
          'date': '2026-12-03',
          'window': [2021, 2025],
          'works': 2
        },
        {'date': 'плохо'},
        {
          'date': '2026-11-05',
          'window': [2021, 2025],
          'works': 1
        },
        {
          'date': '2027-01-03',
          'window': [2022, 2026],
          'works': 3
        },
      ]);
      expect([for (final p in h) p.works], [1, 2, 3]);
      expect(h[0].sameWindow(h[1]), isTrue);
      expect(h[1].sameWindow(h[2]), isFalse);
    });

    test('изменение в процентных пунктах', () {
      expect(formatPpChange(0.055, 0.051, 'ru'), '+0,4$_nb' 'п.$_nb' 'п.');
      expect(formatPpChange(0.04, 0.052, 'en'), '−1.2${_nb}pp');
      expect(formatPpChange(0.05, 0.0502, 'en'), '0 pp');
      expect(formatPpChange(null, 0.05, 'ru'), '');
      expect(formatPpChange(0.07, 0.05, 'uz'), '+2,0${_nb}f.${_nb}p.');
    });

    test('проценты', () {
      expect(formatShare(0.0594, 'ru'), '5,9$_nb%');
      expect(formatShare(0.0594, 'en'), '5.9%');
      expect(formatShare(0.1938, 'uz'), '19$_nb%');
      expect(formatShare(0, 'en'), '0%');
      expect(formatShare(null, 'ru'), '—');
    });
  });

  test('открываются только обычные веб-ссылки', () {
    expect(isSafeWebUrl('https://nuu.uz/'), isTrue);
    expect(isSafeWebUrl('http://example.org/a?b=1'), isTrue);
    for (final bad in [
      'javascript:alert(1)',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///sdcard/x.pdf',
      'tel:+998901234567',
      'content://media/x',
      'https://',
      'nuu.uz',
      '',
    ]) {
      expect(isSafeWebUrl(bad), isFalse, reason: bad);
    }
  });

  group('AnalyticsService', () {
    test('адрес GitHub Pages и кэш', () async {
      final sent = <String>[];
      final cache = MemoryJsonCache();
      final s = AnalyticsService(client: _pages(sent: sent), cache: cache);
      expect(AnalyticsService.defaultBase,
          'https://x9096730-spec.github.io/scinode/analytics/v1');
      final i = await s.index();
      expect(i.orgs.length, 8);
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
        ThemeMode mode = ThemeMode.light,
        http.Client? client}) async {
      await Strings.instance.setLang(lang);
      AnalyticsService.instance = AnalyticsService(
          client: client ?? _pages(), cache: MemoryJsonCache());
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
      expect(find.text(t('an.count', {'n': 8})), findsOneWidget);

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
      expect(find.byKey(const Key('an.pdf_btn')), findsOneWidget);
      expect(find.byKey(const Key('an.pdf_inline')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('an.quality')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(
          find.text('${t('an.q.title')}: ${t('an.q.good')}'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const Key('an.lead_top10')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(t('an.c.lead_top10')), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const Key('an.retracted')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('19'), findsWidgets);
      await tester.scrollUntilVisible(
          find.byKey(const Key('an.citation_check')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(t('an.cc.none')), findsOneWidget);
      expect(find.text('Национальный университет Узбекистана'), findsWidgets);
      await tester.scrollUntilVisible(
          find.byKey(const Key('an.prolific')), -300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(t('an.prolific_author', {'i': 1})), findsOneWidget);
      expect(find.textContaining(t('an.prolific_is_home')), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const Key('an.apc_lead')), -300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(formatMoney(305462, 'USD', 'ru')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('an.sdg')), -300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(t('an.s.sdg')), findsOneWidget);
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
            'an.s.integrity',
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

    testWidgets('история: изменения к прошлому расчёту и смена периода',
        (tester) async {
      // Настоящий отчёт НУУз; прошлые точки истории — тестовые.
      final doc = _j('orgs/$nuu.json');
      final now = Map<String, dynamic>.from((doc['history'] as List).single);
      doc['history'] = [
        {
          ...now,
          'date': '2026-09-03',
          'window': [2020, 2024]
        },
        {...now, 'date': '2026-10-03', 'lead_pp_top10': 0.047, 'oa_share': 0.6},
        now,
      ];
      final client = MockClient((r) async {
        final p = r.url.path.split('/analytics/v1/').last;
        final body = p == 'orgs/$nuu.json'
            ? jsonEncode(doc)
            : File('test/fixtures/analytics/$p').readAsStringSync();
        return http.Response.bytes(utf8.encode(body), 200,
            headers: {'content-type': 'application/json'});
      });
      await pump(tester, const OrgReportScreen(id: nuu), client: client);
      await tester.scrollUntilVisible(find.byKey(const Key('an.history')), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      // 5,1 % против 4,7 % месяцем раньше.
      expect(find.text('+0,4$_nb' 'п.$_nb' 'п.'), findsOneWidget);
      expect(find.textContaining('2021–2025'), findsWidgets);
      expect(tester.takeException(), isNull);
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
      expect(find.byKey(const Key('an.cmp_pdf_btn')), findsOneWidget);
      expect(find.text('9${_nb}059'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text(t('an.cmp.years')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  });
}
