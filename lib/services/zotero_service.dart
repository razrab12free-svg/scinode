import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../auth_service.dart';
import '../models/paper.dart';
import '../models/zotero.dart';

/// Ошибка Zotero: key — ключ неверный или отозван, access — у ключа нет
/// доступа к библиотеке, write — нет права записи, network — нет связи,
/// busy — сервер просит подождать, server — прочие ошибки сервера.
class ZoteroException implements Exception {
  ZoteroException(this.kind);
  final String kind;

  @override
  String toString() => 'ZoteroException($kind)';
}

/// Хранилище ключа (в приложении — защищённое хранилище телефона).
abstract class ZoteroKeyStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

class SecureZoteroKeyStore implements ZoteroKeyStore {
  const SecureZoteroKeyStore();
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read(String name) => _s.read(key: name);
  @override
  Future<void> write(String name, String value) =>
      _s.write(key: name, value: value);
  @override
  Future<void> delete(String name) => _s.delete(key: name);
}

/// Для тестов.
class MemoryZoteroKeyStore implements ZoteroKeyStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String name) async => data[name];
  @override
  Future<void> write(String name, String value) async => data[name] = value;
  @override
  Future<void> delete(String name) async => data.remove(name);
}

/// Подключённый аккаунт Zotero.
class ZoteroAccount {
  const ZoteroAccount({
    required this.key,
    required this.userId,
    required this.username,
    required this.canWrite,
  });
  final String key;
  final int userId;
  final String username;
  final bool canWrite;

  Map<String, dynamic> toJson() =>
      {'k': key, 'u': userId, 'n': username, 'w': canWrite};

  static ZoteroAccount? fromJson(dynamic j) {
    if (j is! Map || j['k'] is! String || j['u'] is! num) return null;
    return ZoteroAccount(
      key: j['k'] as String,
      userId: (j['u'] as num).toInt(),
      username: '${j['n'] ?? ''}',
      canWrite: j['w'] == true,
    );
  }
}

/// Итог экспорта.
class ZoteroExportResult {
  const ZoteroExportResult(
      {this.created = 0, this.skipped = 0, this.failed = const []});
  final int created;

  /// Уже были в Zotero (по DOI).
  final int skipped;
  final List<String> failed;
}

/// Работа с Zotero Web API v3 (https://api.zotero.org).
///
/// Запросы проверены живыми ответами api.zotero.org и кодом официальных
/// клиентов (Zotero, pyzotero): ключ — заголовок `Zotero-API-Key`, версия —
/// `Zotero-API-Version: 3`, сведения о ключе — `GET /keys/current`, запись —
/// `POST /users/<id>/items` пакетами до 50 с `Zotero-Write-Token`.
class ZoteroService extends ChangeNotifier {
  ZoteroService({
    http.Client? client,
    ZoteroKeyStore? store,
    String Function()? owner,
    Duration Function(Duration)? wait,
  })  : _client = client ?? http.Client(),
        _store = store ?? const SecureZoteroKeyStore(),
        _owner = owner ?? (() => AuthService.instance.user?.uid ?? 'local'),
        _wait = wait;

  static ZoteroService instance = ZoteroService();

  final http.Client _client;
  final ZoteroKeyStore _store;
  final String Function() _owner;
  final Duration Function(Duration)? _wait;

  static const host = 'api.zotero.org';
  static const keysUrl = 'https://www.zotero.org/settings/keys';
  static const pageSize = 100;
  static const maxItems = 1000;
  static const writeBatch = 50;
  static const _timeout = Duration(seconds: 30);

  ZoteroAccount? _account;
  String _loadedFor = '';
  bool loaded = false;
  Set<String>? _doiCache;

  ZoteroAccount? get account => _account;
  bool get connected => _account != null;

  String get _storeKey => 'zotero_${_owner()}';

  /// Загружает сохранённое подключение текущего аккаунта Scinode.
  Future<void> ensureLoaded() async {
    final k = _storeKey;
    if (loaded && _loadedFor == k) return;
    _loadedFor = k;
    _account = null;
    _doiCache = null;
    try {
      final raw = await _store.read(k);
      if (raw != null) _account = ZoteroAccount.fromJson(jsonDecode(raw));
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  // ------------------------------------------------------------- запросы

  Map<String, String> _headers(String key, {bool json = false}) => {
        'Zotero-API-Key': key,
        'Zotero-API-Version': '3',
        if (json) 'Content-Type': 'application/json',
      };

  /// Выполняет запрос; при 429/503 один раз ждёт сколько просит сервер.
  Future<http.Response> _send(Future<http.Response> Function() req) async {
    for (var attempt = 0;; attempt++) {
      http.Response r;
      try {
        r = await req().timeout(_timeout);
      } catch (_) {
        throw ZoteroException('network');
      }
      if ((r.statusCode == 429 || r.statusCode == 503) && attempt == 0) {
        final secs = int.tryParse(
                r.headers['retry-after'] ?? r.headers['backoff'] ?? '') ??
            5;
        final d = Duration(seconds: secs.clamp(1, 20));
        await Future<void>.delayed(_wait?.call(d) ?? d);
        continue;
      }
      if (r.statusCode == 429 || r.statusCode == 503) {
        throw ZoteroException('busy');
      }
      if (r.statusCode == 403) throw ZoteroException('key');
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw ZoteroException('server');
      }
      return r;
    }
  }

  dynamic _json(http.Response r) {
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ZoteroException('server');
    }
  }

  ZoteroAccount get _acc {
    final a = _account;
    if (a == null) throw ZoteroException('key');
    return a;
  }

  // ---------------------------------------------------------- подключение

  /// Проверяет ключ и сохраняет подключение.
  Future<ZoteroAccount> connect(String rawKey) async {
    final key = rawKey.trim();
    if (!RegExp(r'^[A-Za-z0-9]{16,40}$').hasMatch(key)) {
      throw ZoteroException('key');
    }
    final r = await _send(() => _client.get(
          Uri.https(host, '/keys/current'),
          headers: _headers(key),
        ));
    final info = ZoteroKeyInfo.fromJson(_json(r));
    if (info == null) throw ZoteroException('key');
    if (!info.canRead) throw ZoteroException('access');
    final acc = ZoteroAccount(
      key: key,
      userId: info.userId,
      username: info.username,
      canWrite: info.canWrite,
    );
    await _store.write(_storeKey, jsonEncode(acc.toJson()));
    _account = acc;
    _doiCache = null;
    notifyListeners();
    return acc;
  }

  /// Забывает ключ на этом телефоне.
  Future<void> disconnect() async {
    await _store.delete(_storeKey);
    _account = null;
    _doiCache = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- чтение

  /// Листает все страницы списка (не больше [cap] записей).
  Future<List<dynamic>> _pages(String path, {int cap = maxItems}) async {
    final a = _acc;
    final out = <dynamic>[];
    for (var start = 0; start < cap; start += pageSize) {
      final r = await _send(() => _client.get(
            Uri.https(host, path, {
              'format': 'json',
              'limit': '$pageSize',
              'start': '$start',
            }),
            headers: _headers(a.key),
          ));
      final page = _json(r);
      if (page is! List) throw ZoteroException('server');
      out.addAll(page);
      final total = int.tryParse(r.headers['total-results'] ?? '');
      if (page.length < pageSize || (total != null && out.length >= total)) {
        break;
      }
    }
    return out;
  }

  Future<List<ZoteroCollection>> collections() async =>
      parseCollections(await _pages('/users/${_acc.userId}/collections'));

  /// Записи верхнего уровня: всей библиотеки или коллекции [collection].
  Future<List<ZoteroItem>> items({String? collection}) async {
    final u = _acc.userId;
    final path = collection == null
        ? '/users/$u/items/top'
        : '/users/$u/collections/$collection/items/top';
    return parseItems(await _pages(path));
  }

  /// DOI всех записей библиотеки (для проверки повторов при экспорте).
  Future<Set<String>> libraryDois({bool refresh = false}) async {
    if (!refresh && _doiCache != null) return _doiCache!;
    final all = await items();
    return _doiCache = {
      for (final i in all)
        if (i.doi != null) i.doi!
    };
  }

  // ---------------------------------------------------------------- запись

  static String _writeToken() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<dynamic> _post(String path, List<Map<String, dynamic>> body) async {
    final a = _acc;
    if (!a.canWrite) throw ZoteroException('write');
    // Один токен на пакет: при повторе сервер не создаст дубли.
    final token = _writeToken();
    final r = await _send(() => _client.post(
          Uri.https(host, path),
          headers: {
            ..._headers(a.key, json: true),
            'Zotero-Write-Token': token,
          },
          body: jsonEncode(body),
        ));
    return _json(r);
  }

  /// Создаёт коллекцию и возвращает её ключ.
  Future<String> createCollection(String name) async {
    final res = ZoteroWriteResult.fromJson(
        await _post('/users/${_acc.userId}/collections', [
      {'name': name.trim(), 'parentCollection': false}
    ]));
    final key = res.created[0];
    if (key == null || key.isEmpty) throw ZoteroException('server');
    return key;
  }

  /// Отправляет статьи в Zotero (в коллекцию [collection] или в корень).
  /// Статьи, чей DOI уже есть в библиотеке Zotero, пропускаются.
  Future<ZoteroExportResult> export(List<Paper> papers,
      {String? collection}) async {
    final have = await libraryDois();
    final send = <Paper>[];
    var skipped = 0;
    final seen = <String>{};
    for (final p in papers) {
      final d = normDoi(p.doi);
      if (d != null && (have.contains(d) || !seen.add(d))) {
        skipped++;
      } else {
        send.add(p);
      }
    }
    var created = 0;
    final failed = <String>[];
    for (var i = 0; i < send.length; i += writeBatch) {
      final chunk = send.sublist(i, min(i + writeBatch, send.length));
      final res = ZoteroWriteResult.fromJson(await _post(
        '/users/${_acc.userId}/items',
        [for (final p in chunk) paperToZotero(p, collection: collection)],
      ));
      created += res.created.length;
      res.failed.forEach((idx, msg) {
        final title = idx < chunk.length ? chunk[idx].title : '';
        failed.add(msg.isEmpty ? title : '$title: $msg');
      });
      for (final idx in res.created.keys) {
        final d = idx < chunk.length ? normDoi(chunk[idx].doi) : null;
        if (d != null) have.add(d);
      }
    }
    return ZoteroExportResult(
        created: created, skipped: skipped, failed: failed);
  }
}

/// Статьи Zotero, которых ещё нет в библиотеке Scinode (по DOI и ключу).
bool inLibrary(ZoteroItem z, List<Paper> library, int userId) {
  final id = z.toPaper(userId).id;
  for (final p in library) {
    if (p.id == id) return true;
    final d = normDoi(p.doi);
    if (d != null && d == z.doi) return true;
  }
  return false;
}
