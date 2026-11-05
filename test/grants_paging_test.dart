import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scinode/screens/grants_screen.dart';
import 'package:scinode/services/grants_service.dart';
import 'package:scinode/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Настоящие ответы search2 (5 ноября 2026): по слову «cancer» 105 объявленных
// конкурсов — две страницы (100 + 5) — и 29 ожидаемых.
String _fx(String name) =>
    File('test/fixtures/grants/$name').readAsStringSync();

final _now = DateTime(2026, 11, 5, 12);

/// Отвечает по startRecordNum и статусу, запоминает тела запросов.
http.Client _gg(List<Map<String, dynamic>> sent, {bool failSecond = false}) =>
    MockClient((req) async {
      final h = {'content-type': 'application/json; charset=utf-8'};
      if (req.url.host != 'api.grants.gov') {
        return http.Response('down', 503);
      }
      final b = jsonDecode(req.body) as Map<String, dynamic>;
      sent.add(b);
      final start = b['startRecordNum'] as int;
      if (failSecond && start > 0) return http.Response('err', 500);
      final String f;
      if (b['oppStatuses'] == 'forecasted') {
        f = 'grantsgov_forecasted_cancer.json';
      } else {
        f = start == 0
            ? 'grantsgov_posted_cancer_p1.json'
            : 'grantsgov_posted_cancer_p2.json';
      }
      return http.Response(_fx(f), 200, headers: h);
    });

/// Вертикальный список конкурсов (а не ленты фильтров и вкладок).
Finder _list() => find
    .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .last;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Grants.gov постранично', () {
    test('первая страница: 100 + 30, счётчики из hitCount', () async {
      final sent = <Map<String, dynamic>>[];
      final svc = GrantsService(client: _gg(sent));
      final p = await svc.grantsGovPage('  cancer ', now: _now);
      expect(sent.length, 2);
      final posted = sent.firstWhere((b) => b['oppStatuses'] == 'posted');
      expect(posted['rows'], 100);
      expect(posted['startRecordNum'], 0);
      expect(posted['keyword'], 'cancer');
      expect(posted['sortBy'], 'closeDate|asc');
      final fc = sent.firstWhere((b) => b['oppStatuses'] == 'forecasted');
      expect(fc['rows'], 30);
      expect(p.postedTotal, 105);
      expect(p.forecastTotal, 29);
      expect(p.postedNext, 100);
      expect(p.forecastNext, 29);
      expect(p.loaded, 129);
      expect(p.total, 134);
      expect(p.hasMore, isTrue);
      expect(p.calls, isNotEmpty);
    });

    test('вторая страница: только объявленные с 100-й записи, потом конец',
        () async {
      final sent = <Map<String, dynamic>>[];
      final svc = GrantsService(client: _gg(sent));
      final p1 = await svc.grantsGovPage('cancer', now: _now);
      sent.clear();
      final p2 = await svc.grantsGovPage('cancer', after: p1, now: _now);
      // Ожидаемые уже все получены — их не спрашиваем.
      expect(sent.length, 1);
      expect(sent.single['oppStatuses'], 'posted');
      expect(sent.single['startRecordNum'], 100);
      expect(p2.calls.length, 5);
      expect(p2.postedNext, 105);
      expect(p2.loaded, 134);
      expect(p2.hasMore, isFalse);
      // Страницы не пересекаются.
      final ids1 = p1.calls.map((c) => c.id).toSet();
      expect(p2.calls.where((c) => ids1.contains(c.id)), isEmpty);
    });

    test('пустая страница — конец, даже если счётчик больше', () async {
      final svc = GrantsService(
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'errorcode': 0,
              'data': {'hitCount': 500, 'oppHits': []},
            }),
            200)),
      );
      final p = await svc.grantsGovPage('x', now: _now);
      expect(p.hasMore, isFalse);
    });
  });

  group('Кнопка «Показать ещё»', () {
    Future<void> pump(WidgetTester tester, http.Client c) async {
      await Strings.instance.setLang('ru');
      GrantsService.instance = GrantsService(client: c);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.2)),
          child: child!,
        ),
        home: const GrantsScreen(),
      ));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    }

    Future<void> search(WidgetTester tester, String q) async {
      await tester.enterText(find.byType(TextField).first, q);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
    }

    // Список длинный (около 130 карточек), листаем крупными шагами.
    Future<void> scrollToMore(WidgetTester tester) async {
      final more = find.byKey(const Key('gr.gg_more'));
      for (var i = 0; i < 200 && more.evaluate().isEmpty; i++) {
        await tester.drag(_list(), const Offset(0, -2000));
        await tester.pump();
      }
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
    }

    testWidgets('дописывает следующие конкурсы и исчезает в конце',
        (tester) async {
      final sent = <Map<String, dynamic>>[];
      await pump(tester, _gg(sent));
      await search(tester, 'cancer');
      final before = int.parse(RegExp(r'Grants\.gov · (\d+)')
          .firstMatch(tester
              .widgetList<Text>(find.textContaining('Grants.gov · '))
              .first
              .data!)!
          .group(1)!);

      await scrollToMore(tester);
      expect(find.text('Grants.gov: загружено 129 из 134'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('gr.gg_more'))).height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('gr.gg_more')));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byKey(const Key('gr.gg_more')), findsNothing);
      expect(find.text('Grants.gov · ${before + 5}'), findsOneWidget);
    });

    testWidgets('ошибка «ещё» не стирает найденное, можно повторить',
        (tester) async {
      final sent = <Map<String, dynamic>>[];
      await pump(tester, _gg(sent, failSecond: true));
      await search(tester, 'cancer');
      await scrollToMore(tester);
      await tester.tap(find.byKey(const Key('gr.gg_more')));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      expect(find.text(t('gr.gg_more_err')), findsOneWidget);
      expect(find.byKey(const Key('gr.gg_more')), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
    });
  });
}
