import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_service.dart';
import '../models/profile.dart';
import '../strings.dart';

class MembersResult {
  const MembersResult(this.items, this.error);
  final List<UserProfile> items;
  final String? error;
}

/// Профиль учёного: черновик хранится на телефоне,
/// опубликованная версия (по желанию) лежит в Firestore.
class ProfileService extends ChangeNotifier {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  UserProfile? mine;
  bool _loaded = false;
  String _loadedFor = '';

  String get _uid => AuthService.instance.user?.uid ?? 'local';
  String get _key => 'profile_$_uid';

  Future<void> ensureLoaded() async {
    final k = _key;
    if (_loaded && _loadedFor == k) return;
    _loaded = true;
    _loadedFor = k;
    mine = null;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(k);
      if (raw != null) {
        mine = UserProfile.fromLocal(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {}
    notifyListeners();
  }

  String _cloudError(Object e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') return t('pf.err.rules');
      return t('pf.err.generic', {'code': e.code});
    }
    return t('pf.err.generic', {'code': e.toString()});
  }

  /// Сохраняет профиль. Возвращает текст ошибки или null.
  Future<String?> save(UserProfile p) async {
    mine = p;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(p.toLocal()));
    } catch (_) {}

    if (!AuthService.instance.ready) {
      return p.published ? t('pf.err.not_ready') : null;
    }
    final uid = AuthService.instance.user?.uid;
    if (uid == null) return p.published ? t('pf.err.not_ready') : null;

    try {
      final ref = FirebaseFirestore.instance.collection('profiles').doc(uid);
      if (p.published) {
        await ref.set({...p.toCloud(), 'u': FieldValue.serverTimestamp()});
      } else {
        await ref.delete();
      }
      return null;
    } catch (e) {
      return _cloudError(e);
    }
  }

  Future<MembersResult> searchMembers(
      {String? tag, String country = ''}) async {
    if (!AuthService.instance.ready) {
      return MembersResult(const [], t('pf.err.not_ready'));
    }
    try {
      Query<Map<String, dynamic>> q =
          FirebaseFirestore.instance.collection('profiles');
      if (tag != null) q = q.where('tg', arrayContains: tag);
      final snap = await q.limit(100).get();
      var items = snap.docs.map((d) {
        final m = d.data();
        final u = m['u'];
        return UserProfile.fromCloud(
          d.id,
          m,
          u is Timestamp ? u.toDate() : null,
        );
      }).toList();
      if (country.isNotEmpty) {
        items = items.where((e) => e.country == country).toList();
      }
      items.sort((a, b) =>
          (b.updated ?? DateTime(2000)).compareTo(a.updated ?? DateTime(2000)));
      return MembersResult(items, null);
    } catch (e) {
      return MembersResult(const [], _cloudError(e));
    }
  }
}
