import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../models/library_view.dart';

/// Запоминает последнюю открытую страницу каждого PDF
/// (на телефоне, отдельно для каждого аккаунта).
class ReadingProgress extends ChangeNotifier {
  ReadingProgress._();
  static final ReadingProgress instance = ReadingProgress._();

  final Map<String, ReadingPos> _pos = {};
  Timer? _debounce;
  bool _loaded = false;
  String _loadedFor = '';

  String get _key => 'reading_${AuthService.instance.user?.uid ?? 'local'}';

  ReadingPos? of(String id) => _pos[id];

  /// Загружает данные текущего аккаунта ([force] — перечитать заново).
  Future<void> ensureLoaded({bool force = false}) async {
    final k = _key;
    if (!force && _loaded && _loadedFor == k) return;
    _loaded = true;
    _loadedFor = k;
    _pos.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(k);
      if (raw != null) {
        final m = jsonDecode(raw);
        if (m is Map) {
          m.forEach((id, v) {
            final r = ReadingPos.fromJson(v);
            if (r != null) _pos[id.toString()] = r;
          });
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Сохраняет страницу [page] из [pages].
  Future<void> save(String id, int page, int pages) async {
    if (page < 1) return;
    final old = _pos[id];
    if (old != null && old.page == page && old.pages == pages) return;
    _pos[id] = ReadingPos(page: page, pages: pages, at: DateTime.now());
    notifyListeners();
    // При листании страницы меняются часто — пишем на диск с задержкой.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _persist);
  }

  /// Немедленно сохраняет отложенные изменения (при закрытии читалки).
  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      await _persist();
    }
  }

  Future<void> remove(String id) async {
    if (_pos.remove(id) == null) return;
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    _pos.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _key,
        jsonEncode({for (final e in _pos.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }
}
