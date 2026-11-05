/// Модели Zotero Web API v3 и перенос статей Zotero ⇄ библиотека Scinode.
library;

import 'paper.dart';

/// Сведения о ключе (`GET /keys/current`).
class ZoteroKeyInfo {
  const ZoteroKeyInfo({
    required this.userId,
    required this.username,
    required this.canRead,
    required this.canWrite,
  });
  final int userId;
  final String username;
  final bool canRead;
  final bool canWrite;

  static ZoteroKeyInfo? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['userID'];
    if (id is! num || id <= 0) return null;
    final user = (j['access'] is Map) ? (j['access'] as Map)['user'] : null;
    bool flag(String k) => user is Map && user[k] == true;
    return ZoteroKeyInfo(
      userId: id.toInt(),
      username: '${j['username'] ?? ''}',
      canRead: flag('library'),
      canWrite: flag('write'),
    );
  }
}

/// Коллекция (папка) Zotero.
class ZoteroCollection {
  const ZoteroCollection({
    required this.key,
    required this.name,
    this.parent,
    this.items = 0,
  });
  final String key;
  final String name;

  /// Ключ родительской коллекции (null — верхний уровень).
  final String? parent;
  final int items;

  static ZoteroCollection? fromJson(dynamic j) {
    if (j is! Map) return null;
    final d = j['data'];
    if (d is! Map) return null;
    final key = '${d['key'] ?? j['key'] ?? ''}';
    if (key.isEmpty) return null;
    final p = d['parentCollection'];
    final meta = j['meta'];
    final n = meta is Map ? meta['numItems'] : null;
    return ZoteroCollection(
      key: key,
      name: '${d['name'] ?? ''}',
      parent: p is String && p.isNotEmpty ? p : null,
      items: n is num ? n.toInt() : 0,
    );
  }
}

/// Коллекции в виде дерева: (коллекция, уровень вложенности), по алфавиту.
List<(ZoteroCollection, int)> collectionTree(List<ZoteroCollection> all) {
  final keys = {for (final c in all) c.key};
  final byParent = <String?, List<ZoteroCollection>>{};
  for (final c in all) {
    // Родитель не найден — показываем на верхнем уровне.
    final p = keys.contains(c.parent) ? c.parent : null;
    byParent.putIfAbsent(p, () => []).add(c);
  }
  for (final l in byParent.values) {
    l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  final out = <(ZoteroCollection, int)>[];
  final seen = <String>{};
  void walk(String? parent, int depth) {
    for (final c in byParent[parent] ?? const <ZoteroCollection>[]) {
      if (!seen.add(c.key)) continue; // защита от циклов
      out.add((c, depth));
      walk(c.key, depth + 1);
    }
  }

  walk(null, 0);
  return out;
}

/// DOI в едином виде: «10.1038/xyz» в нижнем регистре, без префиксов.
String? normDoi(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  s = s.replaceFirst(
      RegExp(r'^(https?://)?(dx\.)?doi\.org/', caseSensitive: false), '');
  s = s.replaceFirst(RegExp(r'^doi:\s*', caseSensitive: false), '');
  s = s.trim();
  if (!RegExp(r'^10\.\d{4,9}/\S+$').hasMatch(s)) return null;
  return s.toLowerCase();
}

/// DOI из поля «Extra» (у типов без поля DOI Zotero пишет «DOI: …»).
String? _doiFromExtra(String extra) {
  for (final line in extra.split('\n')) {
    final m =
        RegExp(r'^\s*DOI:\s*(\S+)', caseSensitive: false).firstMatch(line);
    if (m != null) return normDoi(m[1]);
  }
  return null;
}

/// Запись библиотеки Zotero (только нужные нам поля).
class ZoteroItem {
  const ZoteroItem({
    required this.key,
    required this.type,
    required this.title,
    this.authors = const [],
    this.year,
    this.venue = '',
    this.doi,
    this.url,
    this.abstractText = '',
  });

  final String key;
  final String type;
  final String title;
  final List<String> authors;
  final int? year;
  final String venue;

  /// Нормализованный DOI (см. [normDoi]) или null.
  final String? doi;
  final String? url;
  final String abstractText;

  bool get hasDoi => doi != null;

  static const _skipTypes = {'attachment', 'note', 'annotation'};

  static ZoteroItem? fromJson(dynamic j) {
    if (j is! Map) return null;
    final d = j['data'];
    if (d is! Map) return null;
    final type = '${d['itemType'] ?? ''}';
    if (type.isEmpty || _skipTypes.contains(type)) return null;
    final key = '${d['key'] ?? j['key'] ?? ''}';
    if (key.isEmpty) return null;

    final authors = <String>[];
    for (final c in (d['creators'] as List? ?? const [])) {
      if (c is! Map) continue;
      final name = c['name'];
      final n = name is String && name.trim().isNotEmpty
          ? name.trim()
          : [c['firstName'], c['lastName']]
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .join(' ');
      if (n.isNotEmpty) authors.add(n);
    }

    int? year;
    final meta = j['meta'];
    final parsed = meta is Map ? meta['parsedDate'] : null;
    final y = RegExp(r'(\d{4})').firstMatch(
        parsed is String && parsed.isNotEmpty ? parsed : '${d['date'] ?? ''}');
    if (y != null) year = int.tryParse(y[1]!);

    final venue = [
      'publicationTitle',
      'bookTitle',
      'proceedingsTitle',
      'websiteTitle',
      'publisher'
    ]
        .map((k) => d[k])
        .whereType<String>()
        .map((s) => s.trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');

    final url = '${d['url'] ?? ''}'.trim();
    final title = '${d['title'] ?? ''}'.trim();
    return ZoteroItem(
      key: key,
      type: type,
      title: title.isEmpty ? '—' : title,
      authors: authors,
      year: year,
      venue: venue,
      doi: normDoi(d['DOI'] as String?) ?? _doiFromExtra('${d['extra'] ?? ''}'),
      url: url.startsWith('http') ? url : null,
      abstractText: '${d['abstractNote'] ?? ''}'.trim(),
    );
  }

  /// Статья для библиотеки Scinode.
  Paper toPaper(int userId) => Paper(
        id: 'https://www.zotero.org/users/$userId/items/$key',
        title: title,
        year: year,
        authors: authors,
        venue: venue,
        doi: doi == null ? null : 'https://doi.org/$doi',
        abstractText: abstractText,
        landingUrl: url,
      );
}

/// Записи из ответа списка (`GET .../items`), без вложений и заметок.
List<ZoteroItem> parseItems(dynamic j) => [
      if (j is List)
        for (final x in j)
          if (ZoteroItem.fromJson(x) != null) ZoteroItem.fromJson(x)!,
    ];

List<ZoteroCollection> parseCollections(dynamic j) => [
      if (j is List)
        for (final x in j)
          if (ZoteroCollection.fromJson(x) != null)
            ZoteroCollection.fromJson(x)!,
    ];

/// Разделяет автора «Имя Фамилия» на поля Zotero.
Map<String, String> creatorOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return {'creatorType': 'author', 'name': name.trim()};
  return {
    'creatorType': 'author',
    'firstName': parts.sublist(0, parts.length - 1).join(' '),
    'lastName': parts.last,
  };
}

/// Статья Scinode → новая запись Zotero (журнальная статья).
/// Поля — из шаблона `GET /items/new?itemType=journalArticle`.
Map<String, dynamic> paperToZotero(Paper p, {String? collection}) => {
      'itemType': 'journalArticle',
      'title': p.title,
      'creators': [for (final a in p.authors.take(100)) creatorOf(a)],
      'abstractNote': p.abstractText,
      'publicationTitle': p.venue,
      'date': p.year?.toString() ?? '',
      'DOI': normDoi(p.doi) ?? '',
      'url': p.landingUrl ?? (p.doi ?? ''),
      'tags': [
        {'tag': 'Scinode'}
      ],
      'collections': [if (collection != null) collection],
      'relations': {},
    };

/// Итог записи (`POST .../items`): сколько создано и какие ошибки.
class ZoteroWriteResult {
  const ZoteroWriteResult({required this.created, required this.failed});

  /// Номер в пакете → ключ новой записи.
  final Map<int, String> created;

  /// Номер в пакете → текст ошибки.
  final Map<int, String> failed;

  static ZoteroWriteResult fromJson(dynamic j) {
    final created = <int, String>{};
    final failed = <int, String>{};
    if (j is Map) {
      final s = j['success'];
      if (s is Map) {
        s.forEach((k, v) {
          final i = int.tryParse('$k');
          if (i != null) created[i] = '$v';
        });
      }
      // Новые версии API кладут созданные записи и в successful.
      final full = j['successful'];
      if (full is Map) {
        full.forEach((k, v) {
          final i = int.tryParse('$k');
          if (i != null && v is Map && !created.containsKey(i)) {
            created[i] = '${v['key'] ?? ''}';
          }
        });
      }
      final f = j['failed'];
      if (f is Map) {
        f.forEach((k, v) {
          final i = int.tryParse('$k');
          if (i != null) {
            failed[i] = v is Map ? '${v['message'] ?? v['code'] ?? ''}' : '$v';
          }
        });
      }
    }
    return ZoteroWriteResult(created: created, failed: failed);
  }
}
