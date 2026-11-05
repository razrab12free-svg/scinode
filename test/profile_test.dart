import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/profile.dart';
import 'package:scinode/models/taxonomy.dart';

UserProfile _full() => UserProfile(
      name: ' Ali Valiyev ',
      role: 'phd',
      org: 'NUUz',
      country: 'UZ',
      bio: 'Physics',
      orcid: '0000-0001-2345-6789',
      oaId: 'A1',
      oaName: 'Ali Valiyev',
      tags: const [
        TagRef(tag: 'f31', name: 'Physics and Astronomy'),
        TagRef(tag: 's3104', name: 'Condensed Matter Physics'),
      ],
      published: true,
    );

void main() {
  group('UserProfile.percent', () {
    test('пустой профиль — 0%', () => expect(UserProfile().percent, 0));
    test('заполненный профиль — 100%', () => expect(_full().percent, 100));
    test('только имя и организация — 33%', () {
      expect(UserProfile(name: 'A', org: 'B').percent, 33);
    });
    test('пробелы не считаются заполнением', () {
      expect(UserProfile(name: '   ').percent, 0);
    });
  });

  test('toLocal/fromLocal сохраняют данные', () {
    final p = _full();
    final r = UserProfile.fromLocal(jsonDecode(jsonEncode(p.toLocal())));
    expect(r.toLocal(), p.toLocal());
  });

  test('fromLocal с пустыми данными даёт значения по умолчанию', () {
    final r = UserProfile.fromLocal({});
    expect(r.role, 'researcher');
    expect(r.tags, isEmpty);
    expect(r.published, isFalse);
  });

  group('Firestore (toCloud/fromCloud)', () {
    test('toCloud обрезает пробелы и раскладывает теги', () {
      final c = _full().toCloud();
      expect(c['n'], 'Ali Valiyev');
      expect(c['tg'], ['f31', 's3104']);
      expect(c['tn'], ['Physics and Astronomy', 'Condensed Matter Physics']);
      expect(c.containsKey('updated'), isFalse);
    });

    test('fromCloud восстанавливает профиль', () {
      final when = DateTime.utc(2026, 1, 2);
      final r = UserProfile.fromCloud('uid1', _full().toCloud(), when);
      expect(r.uid, 'uid1');
      expect(r.name, 'Ali Valiyev');
      expect(r.role, 'phd');
      expect(r.tags.map((e) => e.tag), ['f31', 's3104']);
      expect(r.tags.last.name, 'Condensed Matter Physics');
      expect(r.published, isTrue);
      expect(r.updated, when);
    });

    test('fromCloud: названий тегов меньше, чем тегов', () {
      final r = UserProfile.fromCloud(
          'u',
          {
            'tg': ['f1', 'f2'],
            'tn': ['One'],
          },
          null);
      expect(r.tags.length, 2);
      expect(r.tags[1].name, '');
    });
  });

  test('copy создаёт независимую копию тегов', () {
    final p = _full();
    final c = p.copy()..tags.clear();
    expect(p.tags.length, 2);
    expect(c.tags, isEmpty);
  });
}
