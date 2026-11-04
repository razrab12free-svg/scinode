import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../models/paper.dart';

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class DownloadException implements Exception {
  DownloadException(this.kind);

  /// notpdf, toolarge, network, http, nosource, cancelled
  final String kind;
}

class StoredPdf {
  const StoredPdf({required this.path, required this.size, required this.at});
  final String path;
  final int size;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'path': path, 'size': size, 'at': at.millisecondsSinceEpoch};

  factory StoredPdf.fromJson(Map<String, dynamic> j) => StoredPdf(
        path: (j['path'] ?? '').toString(),
        size: j['size'] is int ? j['size'] as int : 0,
        at: DateTime.fromMillisecondsSinceEpoch(
            j['at'] is int ? j['at'] as int : 0),
      );
}

/// Хранилище скачанных PDF (закрытая память приложения).
class PdfStore extends ChangeNotifier {
  PdfStore._();
  static final PdfStore instance = PdfStore._();

  static const int maxBytes = 80 * 1024 * 1024;
  static const _contact = 'razrab12free@gmail.com';
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) Scinode/0.3 (mailto:$_contact)';

  final Map<String, StoredPdf> _files = {};
  final Map<String, double> _progress = {};
  final Map<String, http.Client> _clients = {};
  final Set<String> _cancelled = {};
  bool _loaded = false;
  String _loadedFor = '';

  int get count => _files.length;
  int get totalBytes => _files.values.fold(0, (a, b) => a + b.size);

  String get _key => 'pdfs_${AuthService.instance.user?.uid ?? 'local'}';

  static String idOf(Paper p) {
    final last = p.id.split('/').last.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return last.isEmpty ? 'p${p.id.hashCode.abs()}' : last;
  }

  bool has(String id) => _files.containsKey(id);
  String? pathOf(String id) => _files[id]?.path;
  int sizeOf(String id) => _files[id]?.size ?? 0;
  bool isDownloading(String id) => _clients.containsKey(id);

  /// Прогресс 0..1, либо -1 если размер неизвестен.
  double progressOf(String id) => _progress[id] ?? 0;

  Future<void> ensureLoaded() async {
    final k = _key;
    if (_loaded && _loadedFor == k) return;
    _loaded = true;
    _loadedFor = k;
    _files.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(k);
      if (raw != null) {
        final m = jsonDecode(raw) as Map;
        m.forEach((id, v) {
          final s = StoredPdf.fromJson(Map<String, dynamic>.from(v as Map));
          if (File(s.path).existsSync()) _files[id.toString()] = s;
        });
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _key,
        jsonEncode({for (final e in _files.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/scinode_pdfs');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  void cancel(String id) {
    _cancelled.add(id);
    _clients[id]?.close();
  }

  Future<void> remove(String id) async {
    final s = _files.remove(id);
    if (s != null) {
      try {
        final f = File(s.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    notifyListeners();
    await _save();
  }

  Future<void> clearAll() async {
    for (final s in _files.values) {
      try {
        final f = File(s.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _files.clear();
    notifyListeners();
    await _save();
  }

  /// Скачивает PDF статьи. Бросает [DownloadException].
  Future<void> download(Paper p) async {
    final id = idOf(p);
    if (_clients.containsKey(id) || has(id)) return;
    final client = http.Client();
    _clients[id] = client;
    _progress[id] = 0;
    notifyListeners();
    try {
      final tried = <String>{};
      DownloadException? last;
      var ok = false;

      final direct = p.pdfUrl;
      if (direct != null) {
        tried.add(direct);
        try {
          ok = await _fetch(client, direct, id);
        } on DownloadException catch (e) {
          if (e.kind == 'cancelled') rethrow;
          last = e;
        }
      }

      final doi = p.doiShort;
      if (!ok && doi != null) {
        var urls = <String>[];
        try {
          urls = await _unpaywall(client, doi);
        } catch (_) {
          if (_cancelled.contains(id)) throw DownloadException('cancelled');
        }
        for (final u in urls) {
          if (!tried.add(u)) continue;
          try {
            ok = await _fetch(client, u, id);
            if (ok) break;
          } on DownloadException catch (e) {
            if (e.kind == 'cancelled') rethrow;
            last = e;
          }
        }
      }

      if (!ok) throw last ?? DownloadException('nosource');
    } finally {
      client.close();
      _clients.remove(id);
      _progress.remove(id);
      _cancelled.remove(id);
      notifyListeners();
    }
  }

  Future<List<String>> _unpaywall(http.Client c, String doi) async {
    final uri = Uri.https('api.unpaywall.org', '/v2/$doi', {'email': _contact});
    final res = await c.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return const [];
    final j = jsonDecode(utf8.decode(res.bodyBytes));
    final out = <String>[];
    void add(dynamic loc) {
      if (loc is Map) {
        final u = loc['url_for_pdf'];
        if (u is String && u.isNotEmpty && !out.contains(u)) out.add(u);
      }
    }

    if (j is Map) {
      add(j['best_oa_location']);
      final all = j['oa_locations'];
      if (all is List) {
        for (final l in all) {
          add(l);
        }
      }
    }
    return out;
  }

  Future<bool> _fetch(http.Client client, String rawUrl, String id) async {
    final url = rawUrl.replaceFirst(RegExp(r'^http://'), 'https://');
    final req = http.Request('GET', Uri.parse(url));
    req.headers.addAll({
      'User-Agent': _ua,
      'Accept': 'application/pdf,*/*;q=0.8',
    });

    http.StreamedResponse res;
    try {
      res = await client.send(req).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw DownloadException(_cancelled.contains(id) ? 'cancelled' : 'network');
    }
    if (res.statusCode != 200) throw DownloadException('http');

    final total = res.contentLength ?? 0;
    if (total > maxBytes) throw DownloadException('toolarge');

    final dir = await _dir();
    final tmp = File('${dir.path}/$id.part');
    final sink = tmp.openWrite();
    var received = 0;
    var checked = false;
    var lastNotified = 0.0;
    try {
      await for (final chunk
          in res.stream.timeout(const Duration(seconds: 30))) {
        if (!checked) {
          checked = true;
          final isPdf = chunk.length >= 4 &&
              chunk[0] == 0x25 &&
              chunk[1] == 0x50 &&
              chunk[2] == 0x44 &&
              chunk[3] == 0x46;
          if (!isPdf) throw DownloadException('notpdf');
        }
        received += chunk.length;
        if (received > maxBytes) throw DownloadException('toolarge');
        sink.add(chunk);
        final prog = total > 0 ? received / total : -1.0;
        _progress[id] = prog;
        if (prog < 0 || prog - lastNotified >= 0.01) {
          lastNotified = prog;
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      if (e is DownloadException) rethrow;
      throw DownloadException(_cancelled.contains(id) ? 'cancelled' : 'network');
    }

    if (received < 1024) {
      try {
        await tmp.delete();
      } catch (_) {}
      throw DownloadException('notpdf');
    }

    final f = File('${dir.path}/$id.pdf');
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
    _files[id] = StoredPdf(path: f.path, size: received, at: DateTime.now());
    await _save();
    return true;
  }
}
