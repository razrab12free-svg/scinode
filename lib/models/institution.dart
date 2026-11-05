import 'dart:math' as math;

/// Научная организация (OpenAlex /institutions).
class Institution {
  const Institution({
    required this.id,
    required this.name,
    this.type = '',
    this.city = '',
    this.countryCode = '',
    this.country = '',
    this.lat,
    this.lng,
    this.works = 0,
    this.cited = 0,
    this.hIndex,
    this.homepage,
    this.topics = const [],
    this.activity,
  });

  /// Короткий id, например I47151758.
  final String id;
  final String name;

  /// education, healthcare, company, archive, nonprofit, government,
  /// facility, funder, other.
  final String type;
  final String city;
  final String countryCode;
  final String country;
  final double? lat;
  final double? lng;
  final int works;
  final int cited;
  final int? hIndex;
  final String? homepage;

  /// Ведущие темы (до 5).
  final List<String> topics;

  /// Число работ в выбранном направлении (если включён фильтр направления).
  final int? activity;

  bool get hasGeo => lat != null && lng != null;
  String get openAlexUrl => 'https://openalex.org/$id';

  /// Цитирований на одну работу.
  double get citedPerWork => works > 0 ? cited / works : 0;

  Institution withActivity(int? a) => Institution(
        id: id,
        name: name,
        type: type,
        city: city,
        countryCode: countryCode,
        country: country,
        lat: lat,
        lng: lng,
        works: works,
        cited: cited,
        hIndex: hIndex,
        homepage: homepage,
        topics: topics,
        activity: a,
      );

  factory Institution.fromOpenAlex(Map<String, dynamic> j) {
    final geo = j['geo'];
    final stats = j['summary_stats'];
    final topics = <String>[];
    final tl = j['topics'];
    if (tl is List) {
      for (final t in tl) {
        if (t is Map) {
          final n = _s(t['display_name']);
          if (n != null && topics.length < 5) topics.add(n);
        }
      }
    }
    final h = stats is Map ? stats['h_index'] : null;
    return Institution(
      id: shortId(_s(j['id']) ?? ''),
      name: _s(j['display_name']) ?? '—',
      type: _s(j['type']) ?? '',
      city: geo is Map ? (_s(geo['city']) ?? '') : '',
      countryCode: (geo is Map ? _s(geo['country_code']) : null) ??
          _s(j['country_code']) ??
          '',
      country: geo is Map ? (_s(geo['country']) ?? '') : '',
      lat: geo is Map ? _d(geo['latitude']) : null,
      lng: geo is Map ? _d(geo['longitude']) : null,
      works: _i(j['works_count']),
      cited: _i(j['cited_by_count']),
      hIndex: h is num ? h.toInt() : null,
      homepage: _url(j['homepage_url']),
      topics: topics,
    );
  }
}

/// Одна строка ответа group_by OpenAlex.
class GroupCount {
  const GroupCount(this.id, this.name, this.count);
  final String id;
  final String name;
  final int count;
}

String? _s(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _d(dynamic v) => v is num ? v.toDouble() : null;
int _i(dynamic v) => v is num ? v.toInt() : 0;

/// Принимаем только ссылки http(s) — их можно безопасно открыть.
String? _url(dynamic v) {
  final s = _s(v);
  if (s == null) return null;
  final u = Uri.tryParse(s);
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) return null;
  return s;
}

/// https://openalex.org/I47151758 → I47151758.
String shortId(String id) => id.split('/').last;

/// Список организаций из ответа /institutions (только с координатами).
List<Institution> parseInstitutions(Map<String, dynamic> j) {
  final r = j['results'];
  if (r is! List) return const [];
  return [
    for (final x in r)
      if (x is Map) Institution.fromOpenAlex(Map<String, dynamic>.from(x)),
  ].where((i) => i.hasGeo && i.id.isNotEmpty).toList();
}

/// Разбор group_by. Пропускает пустые ключи («unknown»).
List<GroupCount> parseGroups(Map<String, dynamic> j) {
  final g = j['group_by'];
  if (g is! List) return const [];
  final out = <GroupCount>[];
  for (final x in g) {
    if (x is! Map) continue;
    final key = _s(x['key']);
    if (key == null || !key.contains('openalex.org/')) continue;
    out.add(GroupCount(
      shortId(key),
      (_s(x['key_display_name']) ?? '—').replaceAll(RegExp(r'\s+'), ' '),
      _i(x['count']),
    ));
  }
  return out;
}

/// Партнёры организации [selfId]: без неё самой, первые [limit] по числу работ.
List<GroupCount> topPartners(List<GroupCount> groups, String selfId,
    {int limit = 20}) {
  final list = groups.where((g) => g.id != selfId).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  return list.take(limit).toList();
}

/// Радиус метки по числу работ — логарифмическая шкала от [minR] до [maxR].
double markerRadius(int works, int minWorks, int maxWorks,
    {double minR = 6, double maxR = 22}) {
  if (maxWorks <= minWorks) return (minR + maxR) / 2;
  double l(int v) => math.log(math.max(v, 0) + 1);
  final t =
      ((l(works) - l(minWorks)) / (l(maxWorks) - l(minWorks))).clamp(0.0, 1.0);
  return minR + (maxR - minR) * t;
}

/// Толщина линии партнёрства по числу совместных работ (от 1.5 до 8).
double partnerWidth(int count, int maxCount) {
  if (maxCount <= 0) return 1.5;
  final t = (math.log(count + 1) / math.log(maxCount + 1)).clamp(0.0, 1.0);
  return 1.5 + 6.5 * t;
}

/// Уровень цитируемости 0..3 по цитированиям на работу
/// (<5, 5–15, 15–40, >40).
int citedLevel(double perWork) {
  if (perWork < 5) return 0;
  if (perWork < 15) return 1;
  if (perWork < 40) return 2;
  return 3;
}
