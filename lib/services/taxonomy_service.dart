import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/taxonomy.dart';
import '../strings_science.dart' show fieldNamesLocal;
import '../strings_subfields.dart';

/// Тема OpenAlex (самый подробный уровень, 4 516 тем) — для поиска.
class SciTopic {
  const SciTopic(this.id, this.name, this.subfieldId, this.keywords);
  final String id;
  final String name;
  final String subfieldId;
  final List<String> keywords;
}

class SciDomain {
  const SciDomain(this.id, this.name);
  final String id;
  final String name;
}

class Taxonomy {
  const Taxonomy(this.fields, this.subfields,
      {this.domains = const [],
      this.fieldDomain = const {},
      this.topics = const []});
  final List<SciField> fields;
  final Map<String, List<SciSubfield>> subfields;
  final List<SciDomain> domains;

  /// id области → id домена.
  final Map<String, String> fieldDomain;
  final List<SciTopic> topics;

  SciSubfield? subfield(String id) {
    for (final l in subfields.values) {
      for (final s in l) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  SciField? field(String id) {
    for (final f in fields) {
      if (f.id == id) return f;
    }
    return null;
  }
}

/// Результат поиска направлений: область, раздел или тема (→ её раздел).
class TaxHit {
  const TaxHit({required this.tag, this.topic, this.score = 0});

  /// Что выбирается при нажатии (область или раздел).
  final TagRef tag;

  /// Найденная тема (если совпала тема, а не сам раздел).
  final SciTopic? topic;
  final int score;
}

/// Приводит строку к виду для поиска: нижний регистр, ё→е, без апострофов.
String normTax(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp('[‘’ʻʼ\'`]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Поиск по всем уровням дерева на русском, узбекском и английском,
/// включая привычные названия специальностей (taxonomyAliases).
List<TaxHit> searchTaxonomy(Taxonomy tx, String query, {int limit = 40}) {
  final q = normTax(query);
  if (q.length < 2) return const [];
  final words = q.split(' ');
  int score(String text) {
    final s = normTax(text);
    if (s == q) return 100;
    if (s.startsWith(q)) return 80;
    if (RegExp('(^|[\\s,(/-])${RegExp.escape(q)}').hasMatch(s)) return 60;
    if (words.every(s.contains)) return 40;
    return 0;
  }

  final best = <String, TaxHit>{};
  void add(TaxHit h) {
    final key = '${h.tag.tag}|${h.topic?.id ?? ''}';
    final old = best[key];
    if (old == null || old.score < h.score) best[key] = h;
  }

  for (final f in tx.fields) {
    final row = fieldNamesLocal[f.name] ?? const <String>[];
    final s = [f.name, ...row].map(score).fold(0, (a, b) => a > b ? a : b);
    if (s > 0)
      add(TaxHit(tag: TagRef(tag: 'f${f.id}', name: f.name), score: s + 5));
  }
  for (final l in tx.subfields.values) {
    for (final sf in l) {
      final names = [
        sf.name,
        ...?subfieldNamesLocal[sf.id],
      ];
      var s = names.map(score).fold(0, (a, b) => a > b ? a : b);
      for (final a in taxonomyAliases[sf.id] ?? const <String>[]) {
        final v = score(a);
        if (v > s) s = v;
      }
      if (s > 0) {
        add(TaxHit(tag: TagRef(tag: 's${sf.id}', name: sf.name), score: s + 3));
      }
    }
  }
  for (final tp in tx.topics) {
    var s = score(tp.name);
    for (final k in tp.keywords) {
      final v = score(k) - 10;
      if (v > s) s = v;
    }
    if (s <= 0) continue;
    final sf = tx.subfield(tp.subfieldId);
    if (sf == null) continue;
    add(TaxHit(
        tag: TagRef(tag: 's${sf.id}', name: sf.name), topic: tp, score: s));
  }
  final out = best.values.toList()
    ..sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      // Сначала области и разделы, потом темы.
      final ta = a.topic == null ? 0 : 1, tb = b.topic == null ? 0 : 1;
      return ta.compareTo(tb);
    });
  return out.take(limit).toList();
}

/// Разбор встроенного справочника (официальный список тем OpenAlex v2).
Taxonomy parseTaxonomy(Map<String, dynamic> m) {
  final domains = [
    for (final d in (m['domains'] as List? ?? const []))
      SciDomain('${d['id']}', '${d['n']}'),
  ];
  final fieldDomain = <String, String>{};
  final fields = <SciField>[];
  for (final f in (m['fields'] as List? ?? const [])) {
    fields.add(SciField('${f['id']}', '${f['n']}'));
    fieldDomain['${f['id']}'] = '${f['d']}';
  }
  final subs = <String, List<SciSubfield>>{};
  for (final s in (m['subfields'] as List? ?? const [])) {
    final sf = SciSubfield('${s['id']}', '${s['n']}', '${s['f']}');
    subs.putIfAbsent(sf.fieldId, () => []).add(sf);
  }
  final topics = [
    for (final t in (m['topics'] as List? ?? const []))
      SciTopic('${t['id']}', '${t['n']}', '${t['s']}',
          [for (final k in (t['k'] as List? ?? const [])) '$k']),
  ];
  fields
      .sort((a, b) => localFieldName(a.name).compareTo(localFieldName(b.name)));
  for (final l in subs.values) {
    l.sort((a, b) => localSubfieldName(a.id, a.name)
        .compareTo(localSubfieldName(b.id, b.name)));
  }
  return Taxonomy(fields, subs,
      domains: domains, fieldDomain: fieldDomain, topics: topics);
}

/// Дерево направлений науки: 4 домена → 26 областей → 252 раздела → 4 516 тем.
/// Встроено в приложение: работает без интернета и не тратит лимит OpenAlex.
class TaxonomyService {
  TaxonomyService._();
  static final TaxonomyService instance = TaxonomyService._();

  static const asset = 'assets/taxonomy/openalex_v2.json';

  Future<Taxonomy>? _loading;

  Future<Taxonomy> load() => _loading ??= Future(() async {
        final raw = await rootBundle.loadString(asset);
        return parseTaxonomy(jsonDecode(raw) as Map<String, dynamic>);
      }).catchError((Object e) {
        _loading = null;
        throw e;
      });
}
