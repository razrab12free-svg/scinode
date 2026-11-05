/// Открытые данные из записи ORCID (pub.orcid.org, API v3.0).

/// Приводит ввод к виду 0000-0000-0000-000X: понимает ссылку
/// https://orcid.org/…, пробелы, строчную x и 16 знаков без дефисов.
/// Возвращает null, если это не номер ORCID или не сходится контрольная цифра.
String? normalizeOrcid(String input) {
  var s = input.trim().toUpperCase();
  final m = RegExp(r'ORCID\.ORG/+(.*)$').firstMatch(s);
  if (m != null) s = m.group(1)!;
  s = s.replaceAll(RegExp(r'[\s\-/]'), '');
  if (!RegExp(r'^\d{15}[\dX]$').hasMatch(s)) return null;
  if (!orcidChecksumOk(s)) return null;
  return '${s.substring(0, 4)}-${s.substring(4, 8)}-'
      '${s.substring(8, 12)}-${s.substring(12)}';
}

/// Контрольная цифра ORCID (ISO 7064 MOD 11-2), по описанию на сайте ORCID.
bool orcidChecksumOk(String id) {
  final s = id.replaceAll('-', '');
  if (s.length != 16) return false;
  var total = 0;
  for (var i = 0; i < 15; i++) {
    final d = int.tryParse(s[i]);
    if (d == null) return false;
    total = (total + d) * 2;
  }
  final r = (12 - total % 11) % 11;
  final check = r == 10 ? 'X' : '$r';
  return s[15] == check;
}

/// Место работы из раздела employments.
class OrcidJob {
  OrcidJob({
    required this.org,
    this.country = '',
    this.department = '',
    this.role = '',
    this.startYear,
    this.endYear,
  });

  final String org;
  final String country; // код страны, например UZ
  final String department;
  final String role;
  final int? startYear;
  final int? endYear;

  bool get current => endYear == null;
}

class OrcidPerson {
  OrcidPerson({
    this.name = '',
    this.bio = '',
    this.keywords = const [],
    this.countries = const [],
  });

  final String name;
  final String bio;
  final List<String> keywords;
  final List<String> countries;
}

String _str(Object? v) => v == null ? '' : v.toString().trim();

Object? _at(Object? m, String k) => m is Map ? m[k] : null;

String _val(Object? m, String k) => _str(_at(_at(m, k), 'value'));

int? _year(Object? date) => int.tryParse(_val(date, 'year'));

String _squeeze(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Раздел /person: имя (как в публикациях, иначе имя + фамилия),
/// биография, ключевые слова, страны.
OrcidPerson parseOrcidPerson(Map<String, dynamic> j) {
  final n = j['name'];
  final credit = _val(n, 'credit-name');
  final full = _squeeze('${_val(n, 'given-names')} ${_val(n, 'family-name')}');
  final kw = <String>[];
  final kl = _at(_at(j, 'keywords'), 'keyword');
  if (kl is List) {
    for (final k in kl) {
      final c = _str(_at(k, 'content'));
      if (c.isNotEmpty && !kw.contains(c)) kw.add(c);
    }
  }
  final cs = <String>[];
  final al = _at(_at(j, 'addresses'), 'address');
  if (al is List) {
    for (final a in al) {
      final c = _val(a, 'country').toUpperCase();
      if (c.length == 2 && !cs.contains(c)) cs.add(c);
    }
  }
  return OrcidPerson(
    name: _squeeze(credit.isNotEmpty ? credit : full),
    bio: _str(_at(_at(j, 'biography'), 'content'))
        .replaceAll('\r\n', '\n')
        .trim(),
    keywords: kw,
    countries: cs,
  );
}

/// Раздел /employments: все места работы, сначала текущие и самые новые.
List<OrcidJob> parseOrcidEmployments(Map<String, dynamic> j) {
  final out = <OrcidJob>[];
  final groups = j['affiliation-group'];
  if (groups is! List) return out;
  for (final g in groups) {
    final sums = _at(g, 'summaries');
    if (sums is! List) continue;
    for (final s in sums) {
      final e = _at(s, 'employment-summary');
      final org = _at(e, 'organization');
      final name = _squeeze(_str(_at(org, 'name')));
      if (name.isEmpty) continue;
      out.add(OrcidJob(
        org: name,
        country: _str(_at(_at(org, 'address'), 'country')).toUpperCase(),
        department: _squeeze(_str(_at(e, 'department-name'))),
        role: _squeeze(_str(_at(e, 'role-title'))),
        startYear: _year(_at(e, 'start-date')),
        endYear: _year(_at(e, 'end-date')),
      ));
      // В группе несколько записей об одном месте (из разных источников) —
      // берём первую.
      break;
    }
  }
  int key(OrcidJob x) => x.endYear ?? 99999;
  final indexed = out.asMap().entries.toList()
    ..sort((a, b) {
      final c = key(b.value).compareTo(key(a.value));
      if (c != 0) return c;
      final s = (b.value.startYear ?? 0).compareTo(a.value.startYear ?? 0);
      return s != 0 ? s : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}
