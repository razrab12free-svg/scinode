import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth_service.dart';
import '../models/chat.dart';
import '../models/profile.dart';

/// Ошибка чата (понятная пользователю причина).
class ChatException implements Exception {
  ChatException(this.kind);

  /// rules — нет прав (например, нет опубликованного профиля),
  /// network — нет связи, empty / long — неверный текст, other — прочее.
  final String kind;

  @override
  String toString() => 'ChatException($kind)';
}

/// Переписка между участниками Scinode (Firestore `conversations`).
class ChatService {
  ChatService({FirebaseFirestore? db, String? Function()? uid})
      : _dbOverride = db,
        _uid = uid ?? (() => AuthService.instance.user?.uid);

  static ChatService instance = ChatService();

  final FirebaseFirestore? _dbOverride;
  final String? Function() _uid;
  final Map<String, UserProfile?> _profiles = {};

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Чат доступен: вошёл в аккаунт и Firebase настроен.
  bool get available =>
      _uid() != null && (_dbOverride != null || AuthService.instance.ready);

  String get me {
    final u = _uid();
    if (u == null) throw ChatException('rules');
    return u;
  }

  CollectionReference<Map<String, dynamic>> get _convs =>
      _db.collection('conversations');

  ChatException _wrap(Object e) {
    if (e is ChatException) return e;
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') return ChatException('rules');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return ChatException('network');
      }
    }
    return ChatException('other');
  }

  // ------------------------------------------------------------ чтение

  /// Мои переписки (новые сверху, входящие запросы — первыми).
  Stream<List<Conversation>> conversations() {
    final uid = me;
    return _convs
        .where('members', arrayContains: uid)
        .limit(200)
        .snapshots()
        .map((s) => sortConversations(
              [for (final d in s.docs) Conversation.fromMap(d.id, d.data())],
              uid,
            ));
  }

  /// Одна переписка (null — ещё не создана).
  Stream<Conversation?> conversation(String cid) => _convs
      .doc(cid)
      .snapshots()
      .map((d) => d.exists ? Conversation.fromMap(d.id, d.data()!) : null);

  /// Последние 300 сообщений по времени.
  Stream<List<ChatMessage>> messages(String cid) => _convs
      .doc(cid)
      .collection('messages')
      .orderBy('at')
      .limitToLast(300)
      .snapshots(includeMetadataChanges: false)
      .map((s) => [
            for (final d in s.docs) ChatMessage.fromMap(d.id, d.data()),
          ]);

  /// Опубликованный профиль собеседника (null — профиль удалён или скрыт).
  Future<UserProfile?> profileOf(String uid) async {
    if (_profiles.containsKey(uid)) return _profiles[uid];
    try {
      final d = await _db.collection('profiles').doc(uid).get();
      final p = d.exists
          ? UserProfile.fromCloud(uid, d.data()!, readTime(d.data()!['u']))
          : null;
      _profiles[uid] = p;
      return p;
    } catch (_) {
      return null;
    }
  }

  /// Опубликован ли мой профиль (без него писать нельзя).
  /// Проверяем каждый раз заново: профиль могли только что опубликовать.
  Future<bool> myProfilePublished() async {
    forgetProfile(me);
    return (await profileOf(me)) != null;
  }

  void forgetProfile(String uid) => _profiles.remove(uid);

  // ------------------------------------------------------------ запись

  /// Первое сообщение: создаёт запрос на переписку, если её ещё нет,
  /// иначе просто отправляет сообщение. Возвращает id переписки.
  Future<String> start(String otherUid, String text) async {
    final err = validateMessage(text);
    if (err != null) throw ChatException(err);
    final uid = me;
    final cid = conversationId(uid, otherUid);
    try {
      final ref = _convs.doc(cid);
      final snap = await ref.get();
      if (snap.exists) {
        await send(cid, text);
        return cid;
      }
      final msg = ref.collection('messages').doc();
      final t = text.trim();
      final members = [uid, otherUid]..sort();
      final b = _db.batch()
        ..set(ref, {
          'members': members,
          'status': 'pending',
          'requester': uid,
          'first': msg.id,
          'created': FieldValue.serverTimestamp(),
          'updated': FieldValue.serverTimestamp(),
          'last': {
            't': previewOf(t),
            'from': uid,
            'at': FieldValue.serverTimestamp(),
          },
          'lastRead': {uid: FieldValue.serverTimestamp()},
          'blockedBy': <String>[],
        })
        ..set(msg, {
          'from': uid,
          'text': t,
          'at': FieldValue.serverTimestamp(),
        });
      await b.commit();
      return cid;
    } catch (e) {
      throw _wrap(e);
    }
  }

  /// Отправляет сообщение в существующую переписку.
  Future<void> send(String cid, String text) async {
    final err = validateMessage(text);
    if (err != null) throw ChatException(err);
    final uid = me;
    final t = text.trim();
    final ref = _convs.doc(cid);
    try {
      await (_db.batch()
            ..set(ref.collection('messages').doc(), {
              'from': uid,
              'text': t,
              'at': FieldValue.serverTimestamp(),
            })
            ..update(ref, {
              'last': {
                't': previewOf(t),
                'from': uid,
                'at': FieldValue.serverTimestamp(),
              },
              'updated': FieldValue.serverTimestamp(),
            }))
          .commit();
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<void> _update(String cid, Map<String, Object?> data) async {
    try {
      await _convs.doc(cid).update(data);
    } catch (e) {
      throw _wrap(e);
    }
  }

  Future<void> accept(String cid) => _update(cid, {'status': 'accepted'});
  Future<void> decline(String cid) => _update(cid, {'status': 'declined'});

  /// Отмечает переписку прочитанной (только если есть что отмечать).
  Future<void> markRead(Conversation c) async {
    if (!c.isUnread(me)) return;
    try {
      await _convs
          .doc(c.id)
          .update({'lastRead.$me': FieldValue.serverTimestamp()});
    } catch (_) {
      // Не критично: отметим в следующий раз.
    }
  }

  Future<void> block(String cid) => _update(cid, {
        'blockedBy': FieldValue.arrayUnion([me])
      });
  Future<void> unblock(String cid) => _update(cid, {
        'blockedBy': FieldValue.arrayRemove([me])
      });

  /// Жалоба на сообщение собеседника.
  Future<void> report(String cid, ChatMessage m, String reason) async {
    try {
      await _db.collection('reports').add({
        'reporter': me,
        'cid': cid,
        'mid': m.id,
        'author': m.from,
        'text': m.text.length > maxMessageLength
            ? m.text.substring(0, maxMessageLength)
            : m.text,
        'reason': reason.length > 300 ? reason.substring(0, 300) : reason,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw _wrap(e);
    }
  }

  /// Удаляет все мои переписки вместе с сообщениями (для «Удалить мои данные»).
  /// Возвращает число удалённых переписок.
  Future<int> deleteAllMine() async {
    final uid = me;
    try {
      final convs = await _convs.where('members', arrayContains: uid).get();
      for (final c in convs.docs) {
        // Сначала сообщения (правила проверяют участие по самой переписке).
        while (true) {
          final msgs =
              await c.reference.collection('messages').limit(400).get();
          if (msgs.docs.isEmpty) break;
          final b = _db.batch();
          for (final m in msgs.docs) {
            b.delete(m.reference);
          }
          await b.commit();
        }
        await c.reference.delete();
      }
      return convs.docs.length;
    } catch (e) {
      throw _wrap(e);
    }
  }
}
