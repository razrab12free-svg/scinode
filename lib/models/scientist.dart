import 'taxonomy.dart';

dynamic _d(dynamic m, String k) => m is Map ? m[k] : null;

String? _s(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _last(String url) => url.split('/').last;

int _i(dynamic v) => v is num ? v.toInt() : 0;

/// Учёный (автор из OpenAlex).
class Scientist {
  const Scientist({
    required this.id,
    required this.name,
    this.orcid,
    this.works = 0,
    this.citations = 0,
    this.hIndex = 0,
    this.institution = '',
    this.countryCode = '',
    this.topics = const [],
    this.subfieldTags = const [],
    this.count,
  });

  final String id; // например A5023888391
  final String name;
  final String? orcid;
  final int works;
  final int citations;
  final int hIndex;
  final String institution;
  final String countryCode;
  final List<String> topics;
  final List<TagRef> subfieldTags;
  final int? count; // число работ в выбранной теме

  String get openAlexUrl => 'https://openalex.org/$id';

  factory Scientist.fromOpenAlex(Map<String, dynamic> a, {int? count}) {
    dynamic inst;
    final lki = a['last_known_institutions'];
    if (lki is List && lki.isNotEmpty) inst = lki.first;
    inst ??= a['last_known_institution'];
    if (inst is! Map) {
      final aff = a['affiliations'];
      if (aff is List && aff.isNotEmpty) inst = _d(aff.first, 'institution');
    }

    final names = <String>[];
    final subs = <TagRef>[];
    final seen = <String>{};
    final tl = a['topics'];
    if (tl is List) {
      for (final x in tl) {
        final n = _s(_d(x, 'display_name'));
        if (n != null && names.length < 5) names.add(n);
        final sf = _d(x, 'subfield');
        final sid = _s(_d(sf, 'id'));
        final sn = _s(_d(sf, 'display_name'));
        if (sid != null && sn != null) {
          final tag = 's${_last(sid)}';
          if (seen.add(tag) && subs.length < 5) {
            subs.add(TagRef(tag: tag, name: sn));
          }
        }
      }
    }

    return Scientist(
      id: _last(_s(a['id']) ?? ''),
      name: _s(a['display_name']) ?? '—',
      orcid: _s(a['orcid']),
      works: _i(a['works_count']),
      citations: _i(a['cited_by_count']),
      hIndex: _i(_d(a['summary_stats'], 'h_index')),
      institution: _s(_d(inst, 'display_name')) ?? '',
      countryCode: _s(_d(inst, 'country_code')) ?? '',
      topics: names,
      subfieldTags: subs,
      count: count,
    );
  }
}
