import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scinode/screens/grants_screen.dart';
import 'package:scinode/services/grants_service.dart';

String _fx(String name) =>
    File('test/fixtures/grants/$name').readAsStringSync();

/// Отвечает реальными образцами; NSF «ломаем», чтобы проверить независимость.
http.Client _client() => MockClient((req) async {
      final h = {'content-type': 'application/json; charset=utf-8'};
      switch (req.url.host) {
        case 'api.tech.ec.europa.eu':
          return http.Response(_fx('eu_search.json'), 200, headers: h);
        case 'api.grants.gov':
          if (req.url.path.endsWith('fetchOpportunity')) {
            return http.Response(_fx('grantsgov_fetch.json'), 200, headers: h);
          }
          final f = req.body.contains('forecasted')
              ? 'grantsgov_forecasted.json'
              : 'grantsgov_posted.json';
          return http.Response(_fx(f), 200, headers: h);
        case 'api.reporter.nih.gov':
          return http.Response(_fx('nih_search.json'), 200, headers: h);
        default:
          return http.Response('down', 503);
      }
    });

void main() {
  setUp(() => GrantsService.instance = GrantsService(client: _client()));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: GrantsScreen()));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
  }

  testWidgets('открытые конкурсы загружаются и открывается карточка',
      (tester) async {
    await pump(tester);
    expect(find.text('Гранты'), findsOneWidget);
    expect(find.textContaining('EU · '), findsOneWidget);
    expect(find.textContaining('Grants.gov · '), findsOneWidget);
    // Ближайший дедлайн — сверху (EuropeAid, дедлайн сегодня или уже прошёл
    // в зависимости от даты запуска теста), список не пустой.
    expect(find.byType(Card), findsWidgets);
    expect(find.textContaining('eligibility'), findsWidgets);

    await tester.tap(find.byType(Card).first);
    await tester.pumpAndSettle();
    expect(find.text('Открыть на официальном сайте'), findsOneWidget);
    expect(find.text('Копировать номер'), findsOneWidget);
  });

  testWidgets('ошибка NSF не мешает NIH', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Профинансированные проекты'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Профинансированные проекты'));
    await tester.pumpAndSettle();
    expect(find.text('Попробуйте'), findsOneWidget);

    await tester.tap(find.text('quantum sensing'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('NSF: сервер временно недоступен'), findsOneWidget);
    expect(find.textContaining('Exploring Entangled Photons'), findsOneWidget);
    expect(find.text('NIH · 3'), findsOneWidget);

    await tester.tap(find.textContaining('Exploring Entangled Photons'));
    await tester.pumpAndSettle();
    expect(find.text('Руководитель'), findsOneWidget);
    expect(find.text('Ashok A Deniz'), findsWidgets);
  });
}
