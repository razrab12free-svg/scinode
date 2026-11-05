import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/institution.dart';
import '../models/taxonomy.dart';
import 'openalex_service.dart';

/// Хранилище ответов OpenAlex на телефоне.
abstract class JsonCache {
  Future<Map<String, dynamic>?> get(String key);
  Future<void> put(String key, Map<String, dynamic> value);
}

/// Кэш в файлах (закрытая папка кэша приложения), срок жизни — 24 часа.
class FileJsonCache implements JsonCache {
  FileJsonCache({this.ttl = const Duration(hours: 24)});
  final Duration ttl;
  Directory? _dir;

  Future<Directory> _folder() async {
    final d = _dir;
    if (d != null) return d;
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/openalex_map');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  @override
  Future<Map<String, dynamic>?> get(String key) async {
    try {
      final f = File('${(await _folder()).path}/$key.json');
      if (!await f.exists()) return null;
      final age = DateTime.now().difference(await f.lastModified());
      if (age > ttl) {
        await f.delete();
        return null;
      }
      final j = jsonDecode(await f.readAsString());
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> put(String key, Map<String, dynamic> value) async {
    try {
      final f = File('${(await _folder()).path}/$key.json');
      await f.writeAsString(jsonEncode(value));
    } catch (_) {}
  }
}

/// Кэш в памяти (для тестов).
class MemoryJsonCache implements JsonCache {
  final Map<String, Map<String, dynamic>> data = {};
  @override
  Future<Map<String, dynamic>?> get(String key) async => data[key];
  @override
  Future<void> put(String key, Map<String, dynamic> value) async =>
      data[key] = value;
}

/// Стабильный ключ кэша (FNV-1a, 64 бита) — не зависит от запуска приложения.
String cacheKey(String path, Map<String, String> params) {
  final keys = params.keys.toList()..sort();
  final s = '$path?${keys.map((k) => '$k=${params[k]}').join('&')}';
  var h = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  for (final c in utf8.encode(s)) {
    h ^= c;
    h = (h * prime) & 0xFFFFFFFFFFFFFFFF;
  }
  return h.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}

/// Грубое определение континента по точке на карте (для фильтра OpenAlex
/// `continent`). Возвращает null для океанов и спорных зон.
String? continentAt(double lat, double lng) {
  if (lat < -60) return 'antarctica';
  // Океания: Австралия, Новая Зеландия, острова Тихого океана.
  if (lat < 0 && lng > 110) return 'oceania';
  if (lng < -25) {
    // Америки: граница по Панамскому перешейку.
    return lat > 8 ? 'north_america' : 'south_america';
  }
  if (lng < 60 && lat < 36 && !(lng > 34 && lat > 12)) return 'africa';
  if (lng < 40 && lat >= 36) return 'europe';
  if (lng < 60 && lat > 45) return 'europe';
  return 'asia';
}

/// Данные для карты науки из OpenAlex (с кэшем на 24 часа).
/// Запрос к OpenAlex: путь и параметры → JSON (ключ OpenAlex добавляется сам).
typedef JsonFetch = Future<Map<String, dynamic>> Function(
    String path, Map<String, String> params);

class MapService {
  MapService({JsonFetch? fetch, JsonCache? cache})
      : _fetch = fetch ?? OpenAlexService.instance.getJson,
        _cache = cache ?? FileJsonCache();
  static MapService instance = MapService();

  final JsonFetch _fetch;
  final JsonCache _cache;

  /// Не больше стольких организаций за запрос.
  static const maxInstitutions = 200;

  /// Отсекаем явные ошибки в данных OpenAlex (например, 44 млн работ
  /// у одной лаборатории): у крупнейших реальных организаций их меньше 5 млн.
  static const _worksCap = 5000000;

  static const _select = 'id,display_name,type,geo,works_count,'
      'cited_by_count,summary_stats,homepage_url,topics';

  int get _since => DateTime.now().year - 5;

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> params) async {
    final key = cacheKey(path, params);
    final hit = await _cache.get(key);
    if (hit != null) return hit;
    final j = await _fetch(path, params);
    await _cache.put(key, j);
    return j;
  }

  /// Организации для карты.
  ///
  /// Без [topic] — по числу всех работ. С [topic] (область или
  /// поддисциплина) — по числу работ в этом направлении за последние 5 лет.
  Future<List<Institution>> institutions({
    String country = '',
    String type = '',
    String continent = '',
    TagRef? topic,
  }) async {
    if (topic == null) {
      final f = [
        'is_super_system:false',
        'works_count:<$_worksCap',
        if (country.isNotEmpty) 'country_code:${country.toLowerCase()}',
        if (type.isNotEmpty) 'type:$type',
        if (continent.isNotEmpty && country.isEmpty) 'continent:$continent',
      ];
      final j = await _get('/institutions', {
        'filter': f.join(','),
        'sort': 'works_count:desc',
        'per-page': '$maxInstitutions',
        'select': _select,
      });
      return parseInstitutions(j);
    }

    final f = [
      topic.isField
          ? 'primary_topic.field.id:${topic.rawId}'
          : 'primary_topic.subfield.id:${topic.rawId}',
      'publication_year:>${_since - 1}',
      if (country.isNotEmpty)
        'authorships.institutions.country_code:${country.toLowerCase()}',
      if (type.isNotEmpty) 'authorships.institutions.type:$type',
      if (continent.isNotEmpty && country.isEmpty)
        'authorships.institutions.continent:$continent',
    ];
    final groups = parseGroups(await _get('/works', {
      'filter': f.join(','),
      'group_by': 'authorships.institutions.id',
    }));
    final list = await byIds([for (final g in groups) g.id]);
    final counts = {for (final g in groups) g.id: g.count};
    // group_by учитывает всех соавторов, поэтому страну и тип
    // проверяем ещё раз у самих организаций.
    final out = [
      for (final i in list)
        if ((country.isEmpty ||
                i.countryCode.toUpperCase() == country.toUpperCase()) &&
            (type.isEmpty || i.type == type))
          i.withActivity(counts[i.id]),
    ]..sort((a, b) => (b.activity ?? 0).compareTo(a.activity ?? 0));
    return out.take(maxInstitutions).toList();
  }

  /// Организации по списку id (запросами по 100).
  Future<List<Institution>> byIds(List<String> ids) async {
    final out = <Institution>[];
    for (var i = 0; i < ids.length; i += 100) {
      final part = ids.sublist(i, (i + 100).clamp(0, ids.length));
      if (part.isEmpty) break;
      out.addAll(parseInstitutions(await _get('/institutions', {
        'filter': 'openalex:${part.join('|')}',
        'per-page': '100',
        'select': _select,
      })));
    }
    return out;
  }

  /// Подробные данные одной организации.
  Future<Institution> institution(String id) async {
    final j = await _get('/institutions/$id', {'select': _select});
    return Institution.fromOpenAlex(j);
  }

  /// Топ-10 авторов организации за последние 5 лет.
  Future<List<GroupCount>> topAuthors(String id) async {
    final g = parseGroups(await _get('/works', {
      'filter': 'authorships.institutions.id:$id,'
          'publication_year:>${_since - 1}',
      'group_by': 'authorships.author.id',
    }));
    return g.take(10).toList();
  }

  /// 20 главных партнёров по совместным работам за 5 лет (с координатами).
  Future<List<(Institution, int)>> partners(String id) async {
    final groups = topPartners(
      parseGroups(await _get('/works', {
        'filter': 'authorships.institutions.id:$id,'
            'publication_year:>${_since - 1}',
        'group_by': 'authorships.institutions.id',
      })),
      id,
    );
    final byId = {
      for (final i in await byIds([for (final g in groups) g.id])) i.id: i
    };
    return [
      for (final g in groups)
        if (byId[g.id] != null) (byId[g.id]!, g.count),
    ];
  }
}
