import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/taxonomy.dart';
import 'package:scinode/services/taxonomy_service.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/strings_science.dart';
import 'package:scinode/strings_subfields.dart';
import 'package:scinode/widgets/taxonomy_picker.dart';

void main() {
  final tx = parseTaxonomy(
      jsonDecode(File('assets/taxonomy/openalex_v2.json').readAsStringSync())
          as Map<String, dynamic>);

  setUp(() => Strings.instance.lang = 'ru');

  group('Встроенный справочник OpenAlex', () {
    test('полное дерево: 4 домена, 26 областей, 252 раздела, 4 516 тем', () {
      expect(tx.domains.length, 4);
      expect(tx.fields.length, 26);
      expect(tx.subfields.values.fold(0, (a, l) => a + l.length), 252);
      expect(tx.topics.length, 4516);
      expect(tx.subfield('3304')?.name, 'Education');
      expect(tx.subfield('3304')?.fieldId, '33');
      // Темы указывают на существующие разделы.
      expect(tx.topics.every((t) => tx.subfield(t.subfieldId) != null), isTrue);
    });

    test('у каждой области и каждого раздела есть русское и узбекское имя', () {
      for (final f in tx.fields) {
        expect(fieldNamesLocal[f.name], isNotNull, reason: f.name);
      }
      for (final l in tx.subfields.values) {
        for (final s in l) {
          final row = subfieldNamesLocal[s.id];
          expect(row, isNotNull, reason: s.name);
          expect(row!.length, 2, reason: s.name);
          expect(row.every((x) => x.trim().isNotEmpty), isTrue, reason: s.name);
        }
      }
      for (final d in tx.domains) {
        expect(t('tax.d.${d.id}'), isNot('tax.d.${d.id}'));
      }
      // Синонимы указывают на существующие разделы.
      for (final id in taxonomyAliases.keys) {
        expect(tx.subfield(id), isNotNull, reason: id);
      }
    });

    test('названия на языке интерфейса', () {
      const tag = TagRef(tag: 's3304', name: 'Education');
      expect(tag.label, 'Образование и педагогика');
      Strings.instance.lang = 'uz';
      expect(tag.label, 'Ta‘lim va pedagogika');
      Strings.instance.lang = 'en';
      expect(tag.label, 'Education');
    });
  });

  group('Поиск направлений', () {
    String first(String q) => searchTaxonomy(tx, q).first.tag.tag;

    test('педагогика находится на русском, узбекском и английском', () {
      expect(first('педагогика'), 's3304');
      expect(first('Педагогические науки'), 's3304');
      expect(first('pedagogika'), 's3304');
      expect(first('ta’lim'), 's3304');
      expect(first('education'), 's3304');
      expect(first('дидактика'), 's3304');
    });

    test('привычные названия специальностей', () {
      expect(searchTaxonomy(tx, 'филология').map((h) => h.tag.tag),
          containsAll(['s1203', 's1208', 's3310']));
      expect(first('юриспруденция'), 's3308');
      expect(first('iqtisodiyot'), anyOf('s2002', 'f20'));
      expect(first('химия'), 'f16');
      expect(first('kimyo'), 'f16');
    });

    test('темы и ключевые слова ведут к своему разделу', () {
      final h = searchTaxonomy(tx, 'teacher education');
      expect(h.any((x) => x.topic != null && x.tag.tag == 's3304'), isTrue);
      expect(searchTaxonomy(tx, 'machine learning').map((x) => x.tag.tag),
          contains('s1702'));
      expect(searchTaxonomy(tx, 'q'), isEmpty);
      expect(searchTaxonomy(tx, 'zzzzqqq'), isEmpty);
    });

    test('ё и апострофы не мешают', () {
      expect(normTax('Ta‘lim  ЁЛКА'), 'talim елка');
    });
  });

  testWidgets('окно выбора: поиск «педагогика» и выбор раздела',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    List<TagRef>? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => Center(
            child: FilledButton(
              onPressed: () async => picked = await pickTags(c, multi: false),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    // Справочник читается из assets настоящей асинхронной загрузкой.
    await tester.runAsync(() => TaxonomyService.instance.load());
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    // Области сгруппированы по 4 доменам.
    expect(find.text('СОЦИАЛЬНЫЕ И ГУМАНИТАРНЫЕ НАУКИ'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'педагогика');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Образование и педагогика').first);
    await tester.pumpAndSettle();
    expect(picked?.single.tag, 's3304');
    expect(picked?.single.name, 'Education');
  });
}
