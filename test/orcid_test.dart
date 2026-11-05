import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scinode/models/orcid.dart';
import 'package:scinode/models/profile.dart';
import 'package:scinode/models/scientist.dart';
import 'package:scinode/models/taxonomy.dart';
import 'package:scinode/screens/orcid_fill_sheet.dart';
import 'package:scinode/services/orcid_service.dart';
import 'package:scinode/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Настоящие ответы pub.orcid.org/v3.0 (5 ноября 2026):
// 0000-0002-1825-0097 — демонстрационная запись ORCID (Josiah Carberry),
// 0000-0002-5107-2763 и 0000-0003-2136-2767 — учёные из Узбекистана.
const belov = '0000-0002-5107-2763';
const popkova = '0000-0003-2136-2767';
const carberry = '0000-0002-1825-0097';

String fxRaw(String name) =>
    File('test/fixtures/orcid/$name').readAsStringSync();
Map<String, dynamic> fx(String name) =>
    jsonDecode(fxRaw(name)) as Map<String, dynamic>;

Scientist belovAuthor() =>
    Scientist.fromOpenAlex(fx('openalex_author_$belov.json'));

http.Client orcidClient(
        {Set<String> missing = const {}, List<http.Request>? sent}) =>
    MockClient((r) async {
      sent?.add(r);
      final parts = r.url.pathSegments; // v3.0 / id / section
      final id = parts[1];
      if (missing.contains(id)) {
        return http.Response(fxRaw('not_found.json'), 404);
      }
      return http.Response.bytes(
          utf8.encode(fxRaw('${parts[2]}_$id.json')), 200);
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Номер ORCID', () {
    test('разные способы ввода', () {
      expect(normalizeOrcid(carberry), carberry);
      expect(normalizeOrcid(' https://orcid.org/$carberry '), carberry);
      expect(normalizeOrcid('orcid.org/$belov'), belov);
      expect(normalizeOrcid('0000 0002 5107 2763'), belov);
      expect(normalizeOrcid('0000000251072763'), belov);
      // Контрольная цифра X, строчная тоже понимается.
      expect(normalizeOrcid('0000-0002-9079-593x'), '0000-0002-9079-593X');
    });

    test('опечатки и мусор не принимаются', () {
      expect(normalizeOrcid(''), isNull);
      expect(normalizeOrcid('1234'), isNull);
      expect(normalizeOrcid('0000-0002-1825-0098'), isNull); // контрольная
      expect(normalizeOrcid('0000-0002-1825-009'), isNull);
      expect(normalizeOrcid('abcd-0002-1825-0097'), isNull);
    });

    test('контрольная цифра у всех реальных номеров сходится', () {
      for (final id in [belov, popkova, carberry, '0000-0003-1803-7728']) {
        expect(orcidChecksumOk(id), isTrue, reason: id);
      }
    });
  });

  group('Разбор записи ORCID', () {
    test('имя, биография и ключевые слова', () {
      final p = parseOrcidPerson(fx('person_$carberry.json'));
      expect(p.name, 'Josiah Carberry');
      expect(p.bio, startsWith('Josiah Carberry is a fictitious person.'));
      expect(p.bio, isNot(contains('\r')));
      expect(p.keywords, contains('psychoceramics'));
    });

    test('страны из адресов', () {
      final p = parseOrcidPerson(fx('person_$belov.json'));
      expect(p.name, 'Pavel Belov');
      expect(p.bio, isEmpty);
      expect(p.countries, ['RU', 'UZ']);
    });

    test('места работы: текущие и новые — первыми', () {
      final jobs = parseOrcidEmployments(fx('employments_$belov.json'));
      expect(jobs.map((e) => e.org),
          ['New Uzbekistan University', 'ITMO University']);
      expect(jobs.first.country, 'UZ');
      expect(jobs.first.startYear, 2024);
      expect(jobs.first.current, isTrue);
    });

    test('кириллица в названии организации сохраняется', () {
      final jobs = parseOrcidEmployments(fx('employments_$popkova.json'));
      expect(jobs.length, 4);
      expect(jobs.first.org, 'Armenian State University of Economics');
      expect(jobs.map((e) => e.org),
          contains('Ташкентский государственный экономический университет'));
      expect(jobs.last.startYear, 2016);
    });

    test('пустые и странные ответы не ломают разбор', () {
      expect(parseOrcidPerson({}).name, isEmpty);
      expect(parseOrcidPerson({'name': null, 'keywords': 5}).keywords, isEmpty);
      expect(parseOrcidEmployments({}), isEmpty);
      expect(parseOrcidEmployments({'affiliation-group': 'x'}), isEmpty);
    });
  });

  group('OrcidService', () {
    test('ORCID + автор OpenAlex: всё для профиля', () async {
      final sent = <http.Request>[];
      final svc = OrcidService(
        client: orcidClient(sent: sent),
        findAuthor: (id) async {
          expect(id, belov);
          return belovAuthor();
        },
      );
      final r = await svc.lookup(belov);
      for (final q in sent) {
        expect(q.headers['Accept'], 'application/json');
      }
      expect(sent.map((q) => q.url.toString()).toSet(), {
        'https://pub.orcid.org/v3.0/$belov/person',
        'https://pub.orcid.org/v3.0/$belov/employments',
      });
      expect(r.name, 'Pavel Belov');
      expect(r.org, 'New Uzbekistan University');
      expect(r.country, 'UZ');
      expect(r.author!.id, 'A5080736113');
      expect(r.author!.works, 613);
      expect(r.isEmpty, isFalse);
    });

    test('нет записи в ORCID — понятная ошибка', () async {
      final svc = OrcidService(
        client: orcidClient(missing: {'0000-0001-2345-678X'}),
        findAuthor: (_) async => null,
      );
      expect(
        () => svc.lookup('0000-0001-2345-678X'),
        throwsA(
            isA<OrcidException>().having((e) => e.kind, 'kind', 'notfound')),
      );
    });

    test('нет сети — ошибка network', () async {
      final svc = OrcidService(
        client: MockClient((_) async => throw const SocketException('x')),
        findAuthor: (_) async => null,
      );
      expect(
        () => svc.lookup(belov),
        throwsA(isA<OrcidException>().having((e) => e.kind, 'kind', 'network')),
      );
    });

    test('OpenAlex недоступен — данные ORCID всё равно есть', () async {
      final svc = OrcidService(
        client: orcidClient(),
        findAuthor: (_) async => throw Exception('limit'),
      );
      final r = await svc.lookup(popkova);
      expect(r.author, isNull);
      expect(r.name, 'Elena Popkova');
      expect(r.org, 'Armenian State University of Economics');
      expect(r.country, 'AM');
    });
  });

  group('Подстановка в профиль', () {
    OrcidLookup lookupBelov() => OrcidLookup(
          orcid: belov,
          person: parseOrcidPerson(fx('person_$belov.json')),
          jobs: parseOrcidEmployments(fx('employments_$belov.json')),
          author: belovAuthor(),
        );

    test('пустой профиль заполняется целиком, направления — до 5', () {
      final p = UserProfile();
      final r = lookupBelov();
      applyOrcid(p, r, OrcidChoice());
      expect(p.orcid, belov);
      expect(p.name, 'Pavel Belov');
      expect(p.org, 'New Uzbekistan University');
      expect(p.country, 'UZ');
      expect(p.oaId, 'A5080736113');
      expect(p.oaName, 'Pavel A. Belov');
      expect(p.tags, isNotEmpty);
      expect(p.tags.length, lessThanOrEqualTo(5));
      expect(p.tags.map((e) => e.tag).toSet().length, p.tags.length);
    });

    test('снятые галочки и пустые значения ничего не меняют', () {
      final keep = TagRef(tag: 's9999', name: 'Мой раздел');
      final p = UserProfile(
          name: 'Павел Белов', org: 'НУУз', bio: 'Мой текст', tags: [keep]);
      final r = OrcidLookup(
        orcid: belov,
        person: parseOrcidPerson(fx('person_$belov.json')),
        jobs: const [],
      );
      applyOrcid(
          p,
          r,
          OrcidChoice()
            ..name = false
            ..tags = false);
      expect(p.name, 'Павел Белов');
      expect(p.bio, 'Мой текст'); // в ORCID биографии нет
      expect(p.org, 'НУУз'); // ни ORCID, ни OpenAlex организацию не дали
      expect(p.country, 'RU'); // из адреса
      expect(p.tags, [keep]);
      expect(p.oaId, isEmpty);
    });

    test('длинная биография обрезается до 400 знаков', () {
      final p = UserProfile();
      final r = OrcidLookup(
        orcid: carberry,
        person: OrcidPerson(name: 'X', bio: 'а' * 900),
        jobs: const [],
      );
      applyOrcid(p, r, OrcidChoice());
      expect(p.bio.length, 400);
      expect(p.bio, endsWith('…'));
    });
  });

  group('Окно «Найдено по ORCID»', () {
    for (final lang in ['ru', 'uz', 'en']) {
      testWidgets('узкий телефон, крупный шрифт ($lang)', (tester) async {
        await Strings.instance.setLang(lang);
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final r = OrcidLookup(
          orcid: belov,
          person: parseOrcidPerson(fx('person_$belov.json')),
          jobs: parseOrcidEmployments(fx('employments_$belov.json')),
          author: belovAuthor(),
        );
        final current = UserProfile(bio: 'Мой текст');
        OrcidChoice? got;
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async =>
                      got = await showOrcidFillSheet(context, r, current),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Pavel Belov'), findsOneWidget);
        expect(find.text('New Uzbekistan University'), findsOneWidget);
        expect(find.text(t('orc.author', {'name': 'Pavel A. Belov', 'n': 613})),
            findsOneWidget);

        // Снимаем «Организацию» и подставляем.
        await tester.tap(find.text('New Uzbekistan University'));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('orc.apply')));
        await tester.tap(find.byKey(const Key('orc.apply')));
        await tester.pumpAndSettle();
        expect(got, isNotNull);
        expect(got!.org, isFalse);
        expect(got!.name, isTrue);
        // Свой текст «О себе» по умолчанию не заменяется.
        expect(got!.bio, isFalse);
      });
    }
  });
}
