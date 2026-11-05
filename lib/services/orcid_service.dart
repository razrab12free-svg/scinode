import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/orcid.dart';
import '../models/scientist.dart';
import 'openalex_service.dart';
import 'scientist_service.dart';

/// Ошибка загрузки из ORCID: notfound, network, other.
class OrcidException implements Exception {
  OrcidException(this.kind);
  final String kind;

  @override
  String toString() => 'OrcidException($kind)';
}

/// Всё, что нашлось по номеру ORCID: открытая запись ORCID и автор OpenAlex.
class OrcidLookup {
  OrcidLookup({
    required this.orcid,
    required this.person,
    required this.jobs,
    this.author,
  });

  final String orcid;
  final OrcidPerson person;
  final List<OrcidJob> jobs;

  /// Автор OpenAlex с этим ORCID (публикации и направления) или null.
  final Scientist? author;

  OrcidJob? get job => jobs.isEmpty ? null : jobs.first;

  String get name => person.name.isNotEmpty ? person.name : author?.name ?? '';

  String get org => job?.org ?? author?.institution ?? '';

  String get country {
    final c = job?.country ?? '';
    if (c.isNotEmpty) return c;
    if (person.countries.isNotEmpty) return person.countries.first;
    return author?.countryCode ?? '';
  }

  String get bio => person.bio;

  bool get isEmpty =>
      name.isEmpty && org.isEmpty && bio.isEmpty && author == null;
}

/// Публичный API ORCID (без ключа) + поиск автора в OpenAlex по ORCID.
class OrcidService {
  OrcidService({
    http.Client? client,
    Future<Scientist?> Function(String orcid)? findAuthor,
  })  : _client = client ?? http.Client(),
        _findAuthor = findAuthor ?? _openAlexAuthor;

  static OrcidService instance = OrcidService();

  final http.Client _client;
  final Future<Scientist?> Function(String orcid) _findAuthor;

  static Future<Scientist?> _openAlexAuthor(String orcid) async {
    try {
      return await ScientistService.instance.getAuthor('orcid:$orcid');
    } on SearchException catch (e) {
      if (e.kind == 'notfound') return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _get(String id, String section) async {
    http.Response r;
    try {
      r = await _client.get(
        Uri.https('pub.orcid.org', '/v3.0/$id/$section'),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw OrcidException('network');
    }
    if (r.statusCode == 404) throw OrcidException('notfound');
    if (r.statusCode != 200) throw OrcidException('other');
    try {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    } catch (_) {
      throw OrcidException('other');
    }
  }

  /// [orcid] — уже проверенный номер вида 0000-0000-0000-000X.
  /// Если OpenAlex недоступен, данные ORCID всё равно возвращаются.
  Future<OrcidLookup> lookup(String orcid) async {
    final authorF = _findAuthor(orcid)
        .then<Scientist?>((a) => a, onError: (Object _) => null);
    final res = await Future.wait([
      _get(orcid, 'person'),
      _get(orcid, 'employments'),
    ]);
    return OrcidLookup(
      orcid: orcid,
      person: parseOrcidPerson(res[0]),
      jobs: parseOrcidEmployments(res[1]),
      author: await authorF,
    );
  }
}
