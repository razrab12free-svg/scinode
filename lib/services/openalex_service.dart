import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/paper.dart';

class SearchException implements Exception {
  SearchException(this.kind);

  /// limit, network или other
  final String kind;
}

class SearchResult {
  const SearchResult({
    required this.papers,
    required this.total,
    required this.page,
  });
  final List<Paper> papers;
  final int total;
  final int page;
}

/// Доступ к открытой базе OpenAlex.
class OpenAlexService extends ChangeNotifier {
  OpenAlexService._();
  static final OpenAlexService instance = OpenAlexService._();

  static const _prefsKey = 'openalex_key';
  static const _contact = 'razrab12free@gmail.com';
  static const _select =
      'id,doi,title,publication_year,cited_by_count,authorships,'
      'primary_location,open_access,best_oa_location,'
      'abstract_inverted_index,primary_topic';

  String? apiKey;
  bool get hasKey => (apiKey ?? '').isNotEmpty;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      apiKey = p.getString(_prefsKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setKey(String? key) async {
    final k = (key ?? '').trim();
    apiKey = k.isEmpty ? null : k;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      if (apiKey == null) {
        await p.remove(_prefsKey);
      } else {
        await p.setString(_prefsKey, apiKey!);
      }
    } catch (_) {}
  }

  /// Общий запрос к OpenAlex. Бросает [SearchException].
  Future<Map<String, dynamic>> getJson(
    String path,
    Map<String, String> params,
  ) async {
    final q = Map<String, String>.from(params);
    q['mailto'] = _contact;
    if (hasKey) q['api_key'] = apiKey!;
    final uri = Uri.https('api.openalex.org', path, q);

    http.Response res;
    try {
      res = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw SearchException('network');
    }

    if (res.statusCode == 401 ||
        res.statusCode == 403 ||
        res.statusCode == 409 ||
        res.statusCode == 429) {
      throw SearchException('limit');
    }
    if (res.statusCode != 200) throw SearchException('other');

    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw SearchException('other');
    }
  }

  Future<SearchResult> search({
    required String query,
    int page = 1,
    bool oaOnly = false,
    int? yearFrom,
    String sort = 'relevance',
  }) async {
    final params = <String, String>{
      'search': query,
      'per-page': '20',
      'page': '$page',
      'select': _select,
    };
    final filters = <String>[];
    if (oaOnly) filters.add('open_access.is_oa:true');
    if (yearFrom != null) filters.add('publication_year:>${yearFrom - 1}');
    if (filters.isNotEmpty) params['filter'] = filters.join(',');
    if (sort == 'cited') params['sort'] = 'cited_by_count:desc';
    if (sort == 'newest') params['sort'] = 'publication_date:desc';

    final data = await getJson('/works', params);
    try {
      final papers = (data['results'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Paper.fromOpenAlex(Map<String, dynamic>.from(e)))
          .toList();
      final meta = data['meta'];
      final total = meta is Map && meta['count'] is int
          ? meta['count'] as int
          : papers.length;
      return SearchResult(papers: papers, total: total, page: page);
    } catch (_) {
      throw SearchException('other');
    }
  }
}
