import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/paper.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('Paper.fromOpenAlex (реальный ответ OpenAlex W2741809807)', () {
    final p = Paper.fromOpenAlex(_fixture('work.json'));

    test('основные поля', () {
      expect(p.id, 'https://openalex.org/W2741809807');
      expect(p.title, startsWith('The state of OA'));
      expect(p.year, 2018);
      expect(p.citations, greaterThan(0));
      expect(p.venue, 'PeerJ');
      expect(p.topic, 'Academic Publishing and Open Access');
    });

    test('DOI и ссылки', () {
      expect(p.doi, 'https://doi.org/10.7717/peerj.4375');
      expect(p.doiShort, '10.7717/peerj.4375');
      expect(p.isOa, isTrue);
      expect(p.pdfUrl, isNull); // в ответе pdf_url = null
      expect(p.landingUrl, 'https://doi.org/10.7717/peerj.4375');
      expect(p.articleUrl, p.landingUrl);
    });

    test('авторы и строка авторов', () {
      expect(p.authors.length, 9);
      expect(p.authors.first, 'Heather Piwowar');
      expect(p.authorsLine, startsWith('Heather Piwowar, Jason R Priem, '));
      expect(p.authorsLine, isNot(contains('Lisa Matthias')));
    });

    test('аннотация собирается из inverted index по порядку слов', () {
      expect(
        p.abstractText,
        startsWith('Despite growing interest in Open Access (OA) to scholarly'),
      );
    });
  });

  group('Paper JSON', () {
    test('toJson/fromJson сохраняют все поля', () {
      const p = Paper(
        id: 'W1',
        title: 'T',
        year: 2020,
        citations: 5,
        authors: ['A', 'B'],
        venue: 'V',
        doi: 'https://doi.org/10.1/x',
        abstractText: 'abs',
        isOa: true,
        pdfUrl: 'https://x/p.pdf',
        landingUrl: 'https://x',
        topic: 'Topic',
      );
      final r = Paper.fromJson(jsonDecode(jsonEncode(p.toJson())));
      expect(r.toJson(), p.toJson());
    });

    test('пустые и неверные значения не ломают разбор', () {
      final r =
          Paper.fromJson({'year': '2020', 'doi': '  ', 'citations': null});
      expect(r.id, '');
      expect(r.year, isNull);
      expect(r.citations, 0);
      expect(r.doi, isNull);
      expect(r.authors, isEmpty);
      expect(r.authorsLine, '');
    });

    test('пустой ответ OpenAlex', () {
      final r = Paper.fromOpenAlex({});
      expect(r.title, '—');
      expect(r.abstractText, '');
      expect(r.isOa, isFalse);
    });
  });

  test('doiShort убирает префикс dx.doi.org', () {
    const p = Paper(id: '', title: '', doi: 'http://dx.doi.org/10.5/abc');
    expect(p.doiShort, '10.5/abc');
  });
}
