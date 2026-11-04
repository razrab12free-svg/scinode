import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/taxonomy.dart';
import 'openalex_service.dart';

class Taxonomy {
  const Taxonomy(this.fields, this.subfields);
  final List<SciField> fields;
  final Map<String, List<SciSubfield>> subfields;
}

/// Дерево направлений науки (области и поддисциплины OpenAlex).
class TaxonomyService {
  TaxonomyService._();
  static final TaxonomyService instance = TaxonomyService._();

  static const _key = 'taxonomy_v1';
  static const _maxAge = Duration(days: 30);

  Taxonomy? _cached;

  String _last(String url) => url.split('/').last;

  Future<Taxonomy> load() async {
    final c = _cached;
    if (c != null) return c;

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final at = DateTime.fromMillisecondsSinceEpoch(m['at'] as int);
        if (DateTime.now().difference(at) < _maxAge) {
          final tx = _fromJson(m);
          if (tx.fields.isNotEmpty) {
            _cached = tx;
            return tx;
          }
        }
      }
    } catch (_) {}

    final tx = await _fetch();
    _cached = tx;
    try {
      await prefs?.setString(_key, jsonEncode(_toJson(tx)));
    } catch (_) {}
    return tx;
  }

  Future<Taxonomy> _fetch() async {
    final svc = OpenAlexService.instance;

    final fj = await svc.getJson(
      '/fields',
      {'per-page': '50', 'select': 'id,display_name'},
    );
    final fields = <SciField>[];
    final fr = fj['results'];
    if (fr is List) {
      for (final r in fr) {
        if (r is Map) {
          final id = r['id']?.toString();
          final n = r['display_name']?.toString();
          if (id != null && n != null) fields.add(SciField(_last(id), n));
        }
      }
    }

    final subs = <SciSubfield>[];
    for (var page = 1; page <= 4; page++) {
      final sj = await svc.getJson('/subfields', {
        'per-page': '100',
        'page': '$page',
        'select': 'id,display_name,field',
      });
      final sr = sj['results'];
      if (sr is! List || sr.isEmpty) break;
      for (final r in sr) {
        if (r is Map) {
          final id = r['id']?.toString();
          final n = r['display_name']?.toString();
          final f = r['field'];
          final fid = f is Map ? f['id']?.toString() : null;
          if (id != null && n != null && fid != null) {
            subs.add(SciSubfield(_last(id), n, _last(fid)));
          }
        }
      }
      if (sr.length < 100) break;
    }

    if (fields.isEmpty || subs.isEmpty) throw SearchException('other');
    return _build(fields, subs);
  }

  Taxonomy _build(List<SciField> fields, List<SciSubfield> subs) {
    fields.sort((a, b) => a.name.compareTo(b.name));
    final map = <String, List<SciSubfield>>{};
    for (final s in subs) {
      map.putIfAbsent(s.fieldId, () => []).add(s);
    }
    for (final l in map.values) {
      l.sort((a, b) => a.name.compareTo(b.name));
    }
    return Taxonomy(fields, map);
  }

  Map<String, dynamic> _toJson(Taxonomy t) => {
        'at': DateTime.now().millisecondsSinceEpoch,
        'fields': [
          for (final f in t.fields) {'id': f.id, 'n': f.name},
        ],
        'subs': [
          for (final l in t.subfields.values)
            for (final s in l) {'id': s.id, 'n': s.name, 'f': s.fieldId},
        ],
      };

  Taxonomy _fromJson(Map<String, dynamic> m) {
    final fields = <SciField>[
      for (final f in (m['fields'] as List? ?? const []))
        SciField(
          (f as Map)['id'].toString(),
          f['n'].toString(),
        ),
    ];
    final subs = <SciSubfield>[
      for (final s in (m['subs'] as List? ?? const []))
        SciSubfield(
          (s as Map)['id'].toString(),
          s['n'].toString(),
          s['f'].toString(),
        ),
    ];
    return _build(fields, subs);
  }
}
