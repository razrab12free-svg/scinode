import '../models/scientist.dart';
import '../models/taxonomy.dart';
import 'openalex_service.dart';

/// Поиск учёных в OpenAlex.
class ScientistService {
  ScientistService._();
  static final ScientistService instance = ScientistService._();

  OpenAlexService get _svc => OpenAlexService.instance;

  List<Scientist> _parseAuthors(Map<String, dynamic> j) {
    final r = j['results'];
    if (r is! List) return [];
    return [
      for (final a in r)
        if (a is Map) Scientist.fromOpenAlex(Map<String, dynamic>.from(a)),
    ];
  }

  Future<List<Scientist>> searchByName(String query) async {
    final j = await _svc.getJson(
      '/authors',
      {'search': query, 'per-page': '25'},
    );
    return _parseAuthors(j);
  }

  Future<Scientist> getAuthor(String id) async {
    final short = id.split('/').last;
    final j = await _svc.getJson('/authors/$short', const {});
    return Scientist.fromOpenAlex(j);
  }

  /// Ведущие авторы по теме: считаем работы по выбранному направлению,
  /// ключевым словам и стране, затем подтягиваем данные об авторах.
  Future<List<Scientist>> expertsByTopic({
    String text = '',
    TagRef? tag,
    String country = '',
    bool recent = true,
  }) async {
    final filters = <String>[];
    if (tag != null) {
      filters.add(tag.isField
          ? 'primary_topic.field.id:${tag.rawId}'
          : 'primary_topic.subfield.id:${tag.rawId}');
    }
    if (recent) {
      filters.add('publication_year:>${DateTime.now().year - 6}');
    }
    if (country.isNotEmpty) {
      filters.add('authorships.institutions.country_code:$country');
    }

    final params = <String, String>{'group_by': 'authorships.author.id'};
    if (filters.isNotEmpty) params['filter'] = filters.join(',');
    if (text.isNotEmpty) params['search'] = text;

    final j = await _svc.getJson('/works', params);
    final groups = j['group_by'];
    if (groups is! List) throw SearchException('other');

    final order = <String>[];
    final counts = <String, int>{};
    for (final g in groups) {
      if (g is! Map) continue;
      final key = g['key']?.toString() ?? '';
      if (!key.contains('openalex.org/A')) continue;
      final id = key.split('/').last;
      final c = g['count'];
      counts[id] = c is num ? c.toInt() : 0;
      order.add(id);
      if (order.length >= 50) break;
    }
    if (order.isEmpty) return [];

    final aj = await _svc.getJson('/authors', {
      'filter': 'openalex:${order.join('|')}',
      'per-page': '50',
    });
    final byId = <String, Scientist>{};
    for (final s in _parseAuthors(aj)) {
      byId[s.id] = s;
    }

    final out = <Scientist>[];
    for (final id in order) {
      final s = byId[id];
      if (s == null) continue;
      if (country.isNotEmpty && s.countryCode != country) continue;
      out.add(Scientist(
        id: s.id,
        name: s.name,
        orcid: s.orcid,
        works: s.works,
        citations: s.citations,
        hIndex: s.hIndex,
        institution: s.institution,
        countryCode: s.countryCode,
        topics: s.topics,
        subfieldTags: s.subfieldTags,
        count: counts[id],
      ));
      if (out.length >= 30) break;
    }
    return out;
  }
}
