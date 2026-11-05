import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/scientist.dart';

void main() {
  group('Scientist.fromOpenAlex (реальный ответ OpenAlex A5023888391)', () {
    final j = jsonDecode(File('test/fixtures/author.json').readAsStringSync())
        as Map<String, dynamic>;
    final s = Scientist.fromOpenAlex(j, count: 7);

    test('основные поля', () {
      expect(s.id, 'A5023888391');
      expect(s.name, 'Jason R Priem');
      expect(s.orcid, 'https://orcid.org/0000-0001-6187-6610');
      expect(s.works, greaterThan(0));
      expect(s.citations, greaterThan(0));
      expect(s.hIndex, greaterThan(0));
      expect(s.count, 7);
      expect(s.openAlexUrl, 'https://openalex.org/A5023888391');
    });

    test('организация из last_known_institutions', () {
      expect(s.institution, 'OpenAlex');
      expect(s.countryCode, 'CA');
    });

    test('темы не больше 5, поддисциплины без повторов', () {
      expect(s.topics.length, lessThanOrEqualTo(5));
      expect(s.topics.first, 'scientometrics and bibliometrics research');
      final tags = s.subfieldTags.map((e) => e.tag).toList();
      expect(tags.first, 's1804');
      expect(tags.toSet().length, tags.length);
      expect(tags, contains('s1710'));
    });
  });

  test('запасной вариант: организация из affiliations', () {
    final s = Scientist.fromOpenAlex({
      'id': 'https://openalex.org/A1',
      'display_name': 'X',
      'affiliations': [
        {
          'institution': {'display_name': 'MIT', 'country_code': 'US'},
        },
      ],
    });
    expect(s.institution, 'MIT');
    expect(s.countryCode, 'US');
  });

  test('пустой ответ не ломает разбор', () {
    final s = Scientist.fromOpenAlex({});
    expect(s.id, '');
    expect(s.name, '—');
    expect(s.works, 0);
    expect(s.topics, isEmpty);
    expect(s.subfieldTags, isEmpty);
  });
}
