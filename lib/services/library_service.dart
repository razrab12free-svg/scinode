import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../models/paper.dart';

/// Личная библиотека статей (хранится на телефоне отдельно для каждого аккаунта).
class LibraryService extends ChangeNotifier {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  final List<Paper> _items = [];
  bool _loaded = false;
  String _loadedFor = '';

  List<Paper> get items => List.unmodifiable(_items);

  String get _key {
    final uid = AuthService.instance.user?.uid ?? 'local';
    return 'library_$uid';
  }

  /// Загружает данные текущего аккаунта ([force] — перечитать заново).
  Future<void> ensureLoaded({bool force = false}) async {
    final k = _key;
    if (!force && _loaded && _loadedFor == k) return;
    _loaded = true;
    _loadedFor = k;
    _items.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(k);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          _items.add(Paper.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  bool contains(String id) => _items.any((p) => p.id == id);

  Future<void> toggle(Paper p) async {
    if (contains(p.id)) {
      _items.removeWhere((e) => e.id == p.id);
    } else {
      _items.insert(0, p);
    }
    notifyListeners();
    await _save();
  }

  /// Добавляет статью (если её ещё нет) в начало библиотеки.
  Future<void> add(Paper p) async {
    if (contains(p.id)) return;
    _items.insert(0, p);
    notifyListeners();
    await _save();
  }

  /// Убирает статью из библиотеки.
  Future<void> remove(String id) async {
    final before = _items.length;
    _items.removeWhere((e) => e.id == id);
    if (_items.length == before) return;
    notifyListeners();
    await _save();
  }

  /// Очищает библиотеку этого аккаунта («Удалить мои данные»).
  Future<void> clearAll() async {
    _items.clear();
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(_items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}
