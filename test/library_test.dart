import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/library_view.dart';
import 'package:scinode/models/paper.dart';
import 'package:scinode/screens/library_screen.dart';
import 'package:scinode/screens/pdf_reader_screen.dart';
import 'package:scinode/services/library_service.dart';
import 'package:scinode/services/pdf_store.dart';
import 'package:scinode/services/reading_progress.dart';
import 'package:scinode/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Paper _p(String id, String title,
        {int? year,
        int cited = 0,
        List<String> authors = const [],
        String venue = ''}) =>
    Paper(
        id: id,
        title: title,
        year: year,
        citations: cited,
        authors: authors,
        venue: venue);

void main() {
  // Порядок добавления: новые первыми.
  final real = Paper.fromOpenAlex(
      jsonDecode(File('test/fixtures/work.json').readAsStringSync()));
  final items = [
    _p('W1', 'Graphene transistors',
        year: 2020, cited: 50, authors: ['Ivan Petrov'], venue: 'Nature'),
    real, // 2018, 1306 цитирований, PeerJ
    _p('W3', 'Quantum dots', year: null, cited: 50, authors: ['Ali Valiyev']),
    _p('W4', 'Old graphene paper', year: 2020, cited: 3, venue: 'Science'),
  ];
  final withPdf = {'W1', real.id};
  bool hasPdf(Paper p) => withPdf.contains(p.id);

  group('filterLibrary', () {
    test('все статьи в порядке добавления', () {
      final r = filterLibrary(items, hasPdf: hasPdf);
      expect(r.map((e) => e.id), ['W1', real.id, 'W3', 'W4']);
    });

    test('только скачанные PDF и только без PDF', () {
      expect(
          filterLibrary(items, filter: LibFilter.pdf, hasPdf: hasPdf)
              .map((e) => e.id),
          ['W1', real.id]);
      expect(
          filterLibrary(items, filter: LibFilter.noPdf, hasPdf: hasPdf)
              .map((e) => e.id),
          ['W3', 'W4']);
    });

    test('поиск по названию, автору и журналу без учёта регистра', () {
      expect(
          filterLibrary(items, query: 'GRAPHENE', hasPdf: hasPdf)
              .map((e) => e.id),
          ['W1', 'W4']);
      expect(
          filterLibrary(items, query: 'piwowar', hasPdf: hasPdf)
              .map((e) => e.id),
          [real.id]);
      expect(
          filterLibrary(items, query: 'peerj', hasPdf: hasPdf).map((e) => e.id),
          [real.id]);
      expect(
          filterLibrary(items, query: 'valiyev dots', hasPdf: hasPdf)
              .map((e) => e.id),
          ['W3']);
      expect(
          filterLibrary(items, query: 'graphene science', hasPdf: hasPdf)
              .map((e) => e.id),
          ['W4']);
      expect(
          filterLibrary(items, query: 'нет такого', hasPdf: hasPdf), isEmpty);
    });

    test('поиск вместе с фильтром', () {
      expect(
          filterLibrary(items,
                  query: 'graphene', filter: LibFilter.noPdf, hasPdf: hasPdf)
              .map((e) => e.id),
          ['W4']);
    });

    test(
        'сортировка по году: новые сверху, без года в конце, порядок при равенстве сохраняется',
        () {
      expect(
          filterLibrary(items, sort: LibSort.year, hasPdf: hasPdf)
              .map((e) => e.id),
          ['W1', 'W4', real.id, 'W3']);
    });

    test('сортировка по цитированиям', () {
      expect(
          filterLibrary(items, sort: LibSort.cited, hasPdf: hasPdf)
              .map((e) => e.id),
          [real.id, 'W1', 'W3', 'W4']);
    });

    test('исходный список не меняется', () {
      final copy = List.of(items);
      filterLibrary(items, sort: LibSort.cited, hasPdf: hasPdf);
      expect(items, copy);
    });
  });

  group('ReadingPos', () {
    test('доля прочитанного', () {
      expect(
          const ReadingPos(page: 12, pages: 30).fraction, closeTo(0.4, 1e-9));
      expect(const ReadingPos(page: 5, pages: 0).fraction, 0);
      expect(const ReadingPos(page: 40, pages: 30).fraction, 1);
    });

    test('JSON туда и обратно', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final r = ReadingPos.fromJson(jsonDecode(
          jsonEncode(ReadingPos(page: 7, pages: 20, at: at).toJson())));
      expect(r!.page, 7);
      expect(r.pages, 20);
      expect(r.at, at);
    });

    test('неверные данные', () {
      expect(ReadingPos.fromJson(null), isNull);
      expect(ReadingPos.fromJson({'p': 0}), isNull);
      expect(ReadingPos.fromJson({'p': 'x'}), isNull);
      expect(ReadingPos.fromJson({'p': 3})!.pages, 0);
    });
  });

  test('parsePageNumber', () {
    expect(parsePageNumber('12', 30), 12);
    expect(parsePageNumber(' 1 ', 30), 1);
    expect(parsePageNumber('30', 30), 30);
    expect(parsePageNumber('31', 30), isNull);
    expect(parsePageNumber('0', 30), isNull);
    expect(parsePageNumber('abc', 30), isNull);
    expect(parsePageNumber('', 30), isNull);
  });

  group('ReadingProgress (сохранение на телефоне)', () {
    test('страница сохраняется и переживает перезапуск', () async {
      SharedPreferences.setMockInitialValues({});
      final rp = ReadingProgress.instance;
      await rp.ensureLoaded();
      await rp.clearAll();
      await rp.save('W1', 12, 30);
      expect(rp.of('W1')!.page, 12);
      await rp.save('W1', 13, 30);
      await rp.flush();
      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('reading_local')!) as Map;
      expect(ReadingPos.fromJson(stored['W1'])!.page, 13);
      expect(ReadingPos.fromJson(stored['W1'])!.pages, 30);

      await rp.remove('W1');
      expect(rp.of('W1'), isNull);
      expect(jsonDecode(prefs.getString('reading_local')!), isEmpty);
    });
  });

  group('LibraryService', () {
    test('add не создаёт дублей, remove удаляет', () async {
      SharedPreferences.setMockInitialValues({});
      final lib = LibraryService.instance;
      await lib.ensureLoaded();
      for (final p in List.of(lib.items)) {
        await lib.remove(p.id);
      }
      await lib.add(items[0]);
      await lib.add(items[2]);
      await lib.add(items[0]);
      expect(lib.items.map((e) => e.id), ['W3', 'W1']);
      await lib.remove('W1');
      expect(lib.items.map((e) => e.id), ['W3']);
    });
  });

  testWidgets('экран библиотеки: фильтр, размер PDF и прогресс чтения',
      (tester) async {
    Strings.instance.lang = 'ru';
    final dir = Directory.systemTemp.createTempSync('scinode_lib');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/W1.pdf')
      ..writeAsBytesSync(List.filled(2048, 1));
    final lostPath = '${dir.path}/lost.pdf'; // файла нет — значок не показываем

    SharedPreferences.setMockInitialValues({
      'library_local': jsonEncode([for (final p in items) p.toJson()]),
      'pdfs_local': jsonEncode({
        'W1': {'path': f.path, 'size': 2048, 'at': 0},
        PdfStore.idOf(real): {'path': lostPath, 'size': 100, 'at': 0},
      }),
      'reading_local': jsonEncode({
        'W1': {'p': 12, 'n': 30},
      }),
    });
    // Сервисы — одиночки: перечитываем их данные для этого теста.
    await tester.runAsync(() async {
      await LibraryService.instance.ensureLoaded(force: true);
      await PdfStore.instance.ensureLoaded(force: true);
      await ReadingProgress.instance.ensureLoaded(force: true);
    });

    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: LibraryScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Graphene transistors'), findsOneWidget);
    expect(find.text('PDF · 2 KB'), findsOneWidget);
    expect(find.text('стр. 12 из 30'), findsOneWidget);

    await tester.tap(find.text('Скачанные PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Graphene transistors'), findsOneWidget);
    expect(find.text('Quantum dots'), findsNothing);
    // Пропавший файл не считается скачанным.
    expect(find.textContaining('The state of OA'), findsNothing);

    await tester.tap(find.text('Без PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Quantum dots'), findsOneWidget);
    expect(find.textContaining('The state of OA'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pumpAndSettle();
    expect(find.text('Graphene transistors'), findsOneWidget);
  });
}
