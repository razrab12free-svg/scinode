import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/grant.dart';

/// Ошибка загрузки из одного источника.
class GrantsException implements Exception {
  GrantsException(this.kind);

  /// network — нет связи, server — сервер ответил ошибкой, parse — непонятный ответ.
  final String kind;

  @override
  String toString() => 'GrantsException($kind)';
}

/// Загрузка конкурсов и профинансированных проектов из открытых API.
/// Каждый метод работает независимо, чтобы ошибка одного источника
/// не мешала остальным.
class GrantsService {
  GrantsService({http.Client? client}) : _client = client ?? http.Client();

  /// Можно подменить в тестах.
  static GrantsService instance = GrantsService();

  final http.Client _client;

  static const _timeout = Duration(seconds: 30);
  static const _json = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> _send(
      Future<http.Response> Function() req) async {
    http.Response res;
    try {
      res = await req().timeout(_timeout);
    } catch (_) {
      throw GrantsException('network');
    }
    if (res.statusCode != 200) throw GrantsException('server');
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    throw GrantsException('parse');
  }

  // -------------------------------------------------------------------------
  // EU Funding & Tenders
  // -------------------------------------------------------------------------

  static const _euPageSize = 100;
  static const _euMaxPages = 6;
  static const _euFields = [
    'title',
    'identifier',
    'deadlineDate',
    'startDate',
    'status',
    'type',
    'url',
    'budget',
    'currency',
    'callTitle',
    'typesOfAction',
  ];

  Future<Map<String, dynamic>> _euPage(String text, String query, int page) {
    final uri = Uri.https(
      'api.tech.ec.europa.eu',
      '/search-api/prod/rest/search',
      {
        'apiKey': 'SEDIA',
        'text': text,
        'pageSize': '$_euPageSize',
        'pageNumber': '$page',
      },
    );
    final json = MediaType('application', 'json');
    return _send(() async {
      final r = http.MultipartRequest('POST', uri)
        ..files.addAll([
          http.MultipartFile.fromString('query', query, contentType: json),
          // Без сортировки SEDIA отдаёт страницы с повторами и пропусками.
          http.MultipartFile.fromString(
              'sort', '{"order":"ASC","field":"deadlineDate"}',
              contentType: json),
          http.MultipartFile.fromString('languages', '["en"]',
              contentType: json),
          http.MultipartFile.fromString('displayFields', jsonEncode(_euFields),
              contentType: json),
        ]);
      return http.Response.fromStream(await _client.send(r));
    });
  }

  /// Открытые и скоро открывающиеся конкурсы EU (без закупок).
  Future<List<GrantCall>> euCalls(String keyword, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final today = DateTime.utc(at.year, at.month, at.day).toIso8601String();
    // SEDIA понимает дату только в формате 2026-11-05T00:00:00.000+0000.
    final gte = '${today.substring(0, 23)}+0000';
    final query = jsonEncode({
      'bool': {
        'must': [
          {
            'terms': {'type': euGrantTypes},
          },
          {
            'terms': {
              'status': [euStatusForthcoming, euStatusOpen],
            },
          },
          {
            'range': {
              'deadlineDate': {'gte': gte},
            },
          },
        ],
      },
    });
    final text = keyword.trim().isEmpty ? '***' : keyword.trim();

    final first = await _euPage(text, query, 1);
    final total = first['totalResults'] is num
        ? (first['totalResults'] as num).toInt()
        : 0;
    final pages =
        ((total + _euPageSize - 1) ~/ _euPageSize).clamp(1, _euMaxPages);
    final rest = await Future.wait([
      for (var p = 2; p <= pages; p++) _euPage(text, query, p),
    ]);

    final seen = <String>{};
    final out = <GrantCall>[];
    for (final page in [first, ...rest]) {
      for (final c in parseEuSearch(page, at)) {
        if (seen.add(c.id)) out.add(c);
      }
    }
    sortCalls(out);
    return out;
  }

  // -------------------------------------------------------------------------
  // Grants.gov
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> _ggSearch(Map<String, dynamic> body) => _send(
        () => _client.post(
          Uri.https('api.grants.gov', '/v1/api/search2'),
          headers: _json,
          body: jsonEncode(body),
        ),
      );

  /// Объявленные (posted) и ожидаемые (forecasted) конкурсы Grants.gov.
  Future<List<GrantCall>> grantsGovCalls(String keyword,
      {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final kw = keyword.trim();
    final res = await Future.wait([
      _ggSearch({
        'rows': 100,
        'keyword': kw,
        'oppStatuses': 'posted',
        'sortBy': 'closeDate|asc',
      }),
      _ggSearch({
        'rows': 30,
        'keyword': kw,
        'oppStatuses': 'forecasted',
        'sortBy': 'openDate|desc',
      }),
    ]);
    final seen = <String>{};
    final out = <GrantCall>[];
    for (final r in res) {
      if (r['errorcode'] is num && r['errorcode'] != 0) {
        throw GrantsException('server');
      }
      for (final c in parseGrantsGovSearch(r, at)) {
        if (seen.add(c.id)) out.add(c);
      }
    }
    sortCalls(out);
    return out;
  }

  /// Подробности конкурса Grants.gov.
  Future<GrantCallDetails> grantsGovDetails(String id) async {
    final j = await _send(
      () => _client.post(
        Uri.https('api.grants.gov', '/v1/api/fetchOpportunity'),
        headers: _json,
        body: jsonEncode({'opportunityId': int.tryParse(id) ?? id}),
      ),
    );
    return parseGrantsGovDetails(j);
  }

  // -------------------------------------------------------------------------
  // NIH RePORTER
  // -------------------------------------------------------------------------

  Future<List<FundedProject>> nihProjects(String keyword) async {
    final j = await _send(
      () => _client.post(
        Uri.https('api.reporter.nih.gov', '/v2/projects/search'),
        headers: _json,
        body: jsonEncode({
          'criteria': {
            'advanced_text_search': {
              'operator': 'and',
              'search_field': 'projecttitle,terms,abstracttext',
              'search_text': keyword.trim(),
            },
          },
          'include_fields': [
            'ApplId',
            'ProjectNum',
            'ProjectTitle',
            'Organization',
            'PrincipalInvestigators',
            'AwardAmount',
            'ProjectStartDate',
            'ProjectEndDate',
            'AbstractText',
            'AgencyIcAdmin',
            'ProjectDetailUrl',
          ],
          'offset': 0,
          'limit': 30,
          'sort_field': 'project_start_date',
          'sort_order': 'desc',
        }),
      ),
    );
    return parseNih(j);
  }

  // -------------------------------------------------------------------------
  // NSF
  // -------------------------------------------------------------------------

  Future<List<FundedProject>> nsfAwards(String keyword) async {
    final j = await _send(
      () => _client.get(
        Uri.https('api.nsf.gov', '/services/v1/awards.json', {
          'keyword': nsfKeyword(keyword),
          'rpp': '30',
          'offset': '1',
        }),
        headers: const {'Accept': 'application/json'},
      ),
    );
    return parseNsf(j);
  }
}
