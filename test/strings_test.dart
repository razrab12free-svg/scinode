import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/strings_board.dart';
import 'package:scinode/strings_chat.dart';
import 'package:scinode/strings_extra.dart';
import 'package:scinode/strings_grants.dart';
import 'package:scinode/strings_library.dart';
import 'package:scinode/strings_lock.dart';
import 'package:scinode/strings_orcid.dart';
import 'package:scinode/strings_map.dart';
import 'package:scinode/strings_pdf.dart';
import 'package:scinode/strings_report.dart';
import 'package:scinode/strings_zotero.dart';
import 'package:scinode/strings_notes.dart';
import 'package:scinode/strings_science.dart';

void main() {
  // Правило проекта: каждый текст интерфейса — на трёх языках (ru, uz, en).
  final maps = {
    'board': boardStrings,
    'chat': chatStrings,
    'extra': extraStrings,
    'grants': grantStrings,
    'library': libraryStrings,
    'lock': lockStrings,
    'orcid': orcidStrings,
    'map': mapStrings,
    'pdf': pdfStrings,
    'report': reportStrings,
    'zotero': zoteroStrings,
    'notes': noteStrings,
    'science': scienceStrings,
  };

  test('у каждой строки ровно три непустых перевода', () {
    final bad = <String>[];
    maps.forEach((name, m) {
      m.forEach((k, v) {
        if (v.length != 3 || v.any((s) => s.trim().isEmpty))
          bad.add('$name:$k');
      });
    });
    expect(bad, isEmpty);
  });

  test('ключи не повторяются между файлами строк', () {
    final seen = <String, String>{};
    final dup = <String>[];
    maps.forEach((name, m) {
      for (final k in m.keys) {
        if (seen.containsKey(k)) dup.add('$k (${seen[k]} и $name)');
        seen[k] = name;
      }
    });
    expect(dup, isEmpty);
  });

  test('подстановки {x} одинаковые во всех языках', () {
    final bad = <String>[];
    final re = RegExp(r'\{(\w+)\}');
    maps.forEach((name, m) {
      m.forEach((k, v) {
        final sets = [
          for (final s in v) re.allMatches(s).map((x) => x[1]).toSet()
        ];
        if (sets.length == 3 &&
            !(sets[0].containsAll(sets[1]) &&
                sets[1].containsAll(sets[0]) &&
                sets[0].containsAll(sets[2]) &&
                sets[2].containsAll(sets[0]))) {
          bad.add('$name:$k');
        }
      });
    });
    expect(bad, isEmpty);
  });
}
