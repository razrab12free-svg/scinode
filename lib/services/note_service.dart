import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth_service.dart';
import '../models/note.dart';
import 'board_service.dart' show BoardException, retryDenied;

/// Заметки в Firestore (`notes/{id}`, видит только владелец).
///
/// Записи сразу попадают в локальный кэш и уходят на сервер, когда появится
/// сеть, поэтому интерфейс их не ждёт (см. `fireAndReport`).
class NoteService {
  NoteService({FirebaseFirestore? db, String? Function()? uid})
      : _dbOverride = db,
        _uid = uid ?? (() => AuthService.instance.user?.uid);

  static NoteService instance = NoteService();

  final FirebaseFirestore? _dbOverride;
  final String? Function() _uid;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  bool get available =>
      _uid() != null && (_dbOverride != null || AuthService.instance.ready);

  String get me {
    final u = _uid();
    if (u == null) throw BoardException('rules');
    return u;
  }

  CollectionReference<Map<String, dynamic>> get _notes =>
      _db.collection('notes');

  static const _ts = FieldValue.serverTimestamp;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw BoardException.from(e);
    }
  }

  /// Мои заметки, новые сверху.
  Stream<List<Note>> notes() {
    final uid = me;
    return retryDenied(() => _notes
        .where('o', isEqualTo: uid)
        .limit(1000)
        .snapshots()
        .map((s) =>
            sortNotes([for (final d in s.docs) Note.fromMap(d.id, d.data())])));
  }

  Stream<Note?> note(String id) => retryDenied(() => _notes
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Note.fromMap(d.id, d.data()!) : null));

  static String _cut(String s, int n) => s.length > n ? s.substring(0, n) : s;

  /// Создаёт заметку. Возвращает id сразу; запись завершится в done.
  ({String id, Future<void> done}) create({
    String title = '',
    String body = '',
    NotePaper? paper,
    NoteCard? card,
  }) {
    final ref = _notes.doc();
    final done = _guard(() => ref.set({
          'o': me,
          't': _cut(title.trim(), maxNoteTitle),
          'b': _cut(body, maxNoteBody),
          'p': paper?.toMap(),
          'c': card?.toMap(),
          'cr': _ts(),
          'up': _ts(),
        }));
    return (id: ref.id, done: done);
  }

  Future<void> save(String id, {required String title, required String body}) =>
      _guard(() => _notes.doc(id).update({
            't': _cut(title.trim(), maxNoteTitle),
            'b': _cut(body, maxNoteBody),
            'up': _ts(),
          }));

  Future<void> setPaper(String id, NotePaper? paper) =>
      _guard(() => _notes.doc(id).update({'p': paper?.toMap(), 'up': _ts()}));

  Future<void> setCard(String id, NoteCard? card) =>
      _guard(() => _notes.doc(id).update({'c': card?.toMap(), 'up': _ts()}));

  Future<void> delete(String id) => _guard(() => _notes.doc(id).delete());

  /// «Удалить мои данные»: все мои заметки.
  Future<void> deleteAllMine() => _guard(() async {
        final uid = me;
        while (true) {
          final s = await _notes.where('o', isEqualTo: uid).limit(200).get();
          if (s.docs.isEmpty) break;
          final b = _db.batch();
          for (final d in s.docs) {
            b.delete(d.reference);
          }
          await b.commit();
        }
      });
}
