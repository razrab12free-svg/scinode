import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/analytics.dart';
import 'map_service.dart' show JsonCache, FileJsonCache;

/// Ошибка загрузки Аналитики: network — нет связи; notready — данные ещё
/// не опубликованы; update — нужен новый Scinode (новая схема); other.
class AnalyticsException implements Exception {
  AnalyticsException(this.kind);
  final String kind;

  @override
  String toString() => 'AnalyticsException($kind)';
}

/// Готовые отчёты «Scinode Аналитика» с GitHub Pages (обновляются раз
/// в месяц), с кэшем на телефоне на 24 часа.
class AnalyticsService {
  AnalyticsService({http.Client? client, JsonCache? cache, String? base})
      : _client = client ?? http.Client(),
        _cache = cache ?? FileJsonCache(folder: 'analytics'),
        base = base ?? defaultBase;

  static const defaultBase =
      'https://x9096730-spec.github.io/scinode/analytics/v$analyticsSchema';

  static AnalyticsService instance = AnalyticsService();

  final http.Client _client;
  final JsonCache _cache;
  final String base;

  AnalyticsIndex? _index;
  final Map<String, OrgReport> _reports = {};

  Future<Map<String, dynamic>> _get(String path) async {
    final key = 'v${analyticsSchema}_${path.replaceAll(RegExp(r'[^\w]'), '_')}';
    final hit = await _cache.get(key);
    if (hit != null) return hit;
    http.Response r;
    try {
      r = await _client.get(Uri.parse('$base/$path'), headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw AnalyticsException('network');
    }
    if (r.statusCode == 404) throw AnalyticsException('notready');
    if (r.statusCode != 200) throw AnalyticsException('other');
    Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    } catch (_) {
      throw AnalyticsException('other');
    }
    final schema = j['schema'];
    if (schema is num && schema.toInt() > analyticsSchema) {
      throw AnalyticsException('update');
    }
    await _cache.put(key, j);
    return j;
  }

  /// Список организаций (самые крупные — первыми).
  Future<AnalyticsIndex> index({bool refresh = false}) async {
    final c = _index;
    if (c != null && !refresh) return c;
    final idx = AnalyticsIndex.fromJson(await _get('index.json'));
    _index = idx;
    return idx;
  }

  /// Отчёт по организации (id вида I47151758) или по стране (UZ).
  Future<OrgReport> report(String id) async {
    final c = _reports[id];
    if (c != null) return c;
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(id)) {
      throw AnalyticsException('other');
    }
    final r = OrgReport.fromJson(await _get('orgs/$id.json'));
    _reports[id] = r;
    return r;
  }
}
