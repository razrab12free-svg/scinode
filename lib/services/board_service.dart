import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth_service.dart';
import '../models/board.dart';

/// Ошибка работы с досками.
class BoardException implements Exception {
  BoardException(this.kind);

  /// rules — нет прав, network — нет связи, other — прочее.
  final String kind;

  @override
  String toString() => 'BoardException($kind)';

  static BoardException from(Object e) {
    if (e is BoardException) return e;
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') return BoardException('rules');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return BoardException('network');
      }
    }
    return BoardException('other');
  }
}

/// Карточка, создаваемая вместе с доской.
class NewCard {
  const NewCard({
    required this.title,
    required this.column,
    this.due,
    this.grants = const [],
  });
  final String title;
  final int column;
  final DateTime? due;
  final List<LinkedGrant> grants;
}

/// Канбан-доски в Firestore.
///
/// Запись идёт сразу в локальный кэш Firestore и отправляется на сервер,
/// когда появится сеть, поэтому интерфейс не должен ждать завершения
/// записей (кроме случаев, когда нужен результат).
class BoardService {
  BoardService({FirebaseFirestore? db, String? Function()? uid, Random? rnd})
      : _dbOverride = db,
        _uid = uid ?? (() => AuthService.instance.user?.uid),
        _rnd = rnd ?? Random();

  static BoardService instance = BoardService();

  final FirebaseFirestore? _dbOverride;
  final String? Function() _uid;
  final Random _rnd;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  bool get available =>
      _uid() != null && (_dbOverride != null || AuthService.instance.ready);

  String get me {
    final u = _uid();
    if (u == null) throw BoardException('rules');
    return u;
  }

  CollectionReference<Map<String, dynamic>> get _boards =>
      _db.collection('boards');
  CollectionReference<Map<String, dynamic>> _cards(String bid) =>
      _boards.doc(bid).collection('cards');
  CollectionReference<Map<String, dynamic>> _activity(String bid) =>
      _boards.doc(bid).collection('activity');

  /// Короткий случайный id (колонки, метки).
  String newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (_) => chars[_rnd.nextInt(chars.length)]).join();
  }

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw BoardException.from(e);
    }
  }

  static const _ts = FieldValue.serverTimestamp;

  // --------------------------------------------------------------- чтение

  /// Мои доски (новые изменения сверху, архив в конце).
  Stream<List<Board>> boards() {
    final uid = me;
    return _boards.where('mb', arrayContains: uid).limit(100).snapshots().map(
          (s) => [for (final d in s.docs) Board.fromMap(d.id, d.data())]
            ..sort((a, b) {
              if (a.archived != b.archived) return a.archived ? 1 : -1;
              final ua = a.updated, ub = b.updated;
              if (ua == null && ub == null) return a.name.compareTo(b.name);
              if (ua == null) return -1;
              if (ub == null) return 1;
              return ub.compareTo(ua);
            }),
        );
  }

  Stream<Board?> board(String bid) => _boards
      .doc(bid)
      .snapshots()
      .map((d) => d.exists ? Board.fromMap(d.id, d.data()!) : null);

  Stream<List<TaskCard>> cards(String bid) =>
      _cards(bid).limit(500).snapshots().map((s) =>
          [for (final d in s.docs) TaskCard.fromMap(d.id, bid, d.data())]);

  Stream<List<CardComment>> comments(String bid, String cid) => _cards(bid)
      .doc(cid)
      .collection('comments')
      .orderBy('at')
      .limitToLast(200)
      .snapshots()
      .map(
          (s) => [for (final d in s.docs) CardComment.fromMap(d.id, d.data())]);

  Stream<List<BoardActivity>> activity(String bid) => _activity(bid)
      .orderBy('at', descending: true)
      .limit(200)
      .snapshots()
      .map((s) =>
          [for (final d in s.docs) BoardActivity.fromMap(d.id, d.data())]);

  /// Мои задачи по всем доскам: назначенные мне и все задачи личных досок.
  Stream<List<MyTask>> myTasks() {
    final uid = me;
    late StreamController<List<MyTask>> ctrl;
    StreamSubscription<List<Board>>? boardsSub;
    final cardSubs = <String, StreamSubscription>{};
    final boardsById = <String, Board>{};
    final cardsByBoard = <String, List<TaskCard>>{};

    void emit() {
      if (ctrl.isClosed) return;
      final out = <MyTask>[];
      for (final e in cardsByBoard.entries) {
        final b = boardsById[e.key];
        if (b == null || b.archived) continue;
        for (final c in e.value) {
          if (isMyTask(b, c, uid)) out.add(MyTask(b, c));
        }
      }
      ctrl.add(out);
    }

    void onBoards(List<Board> list) {
      boardsById
        ..clear()
        ..addEntries(list.map((b) => MapEntry(b.id, b)));
      // Отписываемся от удалённых досок.
      for (final id in cardSubs.keys.toList()) {
        if (!boardsById.containsKey(id)) {
          cardSubs.remove(id)?.cancel();
          cardsByBoard.remove(id);
        }
      }
      for (final b in list) {
        if (cardSubs.containsKey(b.id) || b.archived) continue;
        // В общих досках берём только назначенные мне карточки.
        final q = b.isShared
            ? _cards(b.id).where('as', arrayContains: uid)
            : _cards(b.id);
        cardSubs[b.id] = q.limit(300).snapshots().listen((s) {
          cardsByBoard[b.id] = [
            for (final d in s.docs) TaskCard.fromMap(d.id, b.id, d.data()),
          ];
          emit();
        }, onError: (_) {
          cardsByBoard.remove(b.id);
          emit();
        });
      }
      emit();
    }

    ctrl = StreamController<List<MyTask>>(
      onListen: () {
        boardsSub = boards().listen(onBoards, onError: ctrl.addError);
      },
      onCancel: () async {
        await boardsSub?.cancel();
        for (final s in cardSubs.values) {
          await s.cancel();
        }
        cardSubs.clear();
      },
    );
    return ctrl.stream;
  }

  // ---------------------------------------------------------------- доски

  /// Создаёт доску (с колонками и стартовыми карточками шаблона).
  /// [columns] — названия колонок; последняя отмечается как «Готово».
  /// [cards] — (название, индекс колонки).
  /// Возвращает id доски сразу; запись завершится в [done].
  ({String id, Future<void> done}) createBoard({
    required String name,
    required String template,
    required int color,
    required String icon,
    required List<String> columns,
    List<(String, int)> cards = const [],
    List<NewCard> extra = const [],
  }) {
    final uid = me;
    final ref = _boards.doc();
    final cols = [
      for (var i = 0; i < columns.length; i++)
        BoardColumn(
          id: newId(),
          name: columns[i],
          done: i == columns.length - 1,
        ),
    ];
    final b = _db.batch()
      ..set(ref, {
        'n': name.trim(),
        'c': color,
        'ic': icon,
        'ow': uid,
        'mb': [uid],
        'rl': {uid: 'owner'},
        'cols': [for (final c in cols) c.toMap()],
        'lbs': <Map<String, dynamic>>[],
        'ar': false,
        'tpl': template,
        'cr': _ts(),
        'up': _ts(),
      });
    var order = orderStep;
    final all = [
      for (final (title, col) in cards) NewCard(title: title, column: col),
      ...extra,
    ];
    for (final c in all) {
      b.set(
          ref.collection('cards').doc(),
          _newCard(
            title: c.title,
            colId: cols[c.column.clamp(0, cols.length - 1)].id,
            order: order,
            grants: c.grants,
            due: c.due,
          ));
      order += orderStep;
    }
    return (id: ref.id, done: _guard(() => b.commit()));
  }

  Map<String, dynamic> _newCard({
    required String title,
    required String colId,
    required double order,
    DateTime? due,
    List<LinkedGrant> grants = const [],
    List<LinkedPaper> papers = const [],
    List<String> assignees = const [],
  }) =>
      {
        't': title.trim(),
        'd': '',
        'col': colId,
        'o': order,
        'due': due == null ? null : Timestamp.fromDate(due),
        'p': 1,
        'lb': <String>[],
        'as': assignees,
        'ck': <Map<String, dynamic>>[],
        'pp': [for (final p in papers) p.toMap()],
        'gr': [for (final g in grants) g.toMap()],
        'by': me,
        'cr': _ts(),
        'up': _ts(),
        'dn': null,
      };

  Future<void> updateBoard(String bid, Map<String, Object?> data) =>
      _guard(() => _boards.doc(bid).update({...data, 'up': _ts()}));

  Future<void> rename(String bid, String name) =>
      updateBoard(bid, {'n': name.trim()});

  Future<void> setLook(String bid, {int? color, String? icon}) =>
      updateBoard(bid, {
        if (color != null) 'c': color,
        if (icon != null) 'ic': icon,
      });

  Future<void> setArchived(String bid, bool v) => updateBoard(bid, {'ar': v});

  Future<void> setColumns(String bid, List<BoardColumn> cols) =>
      updateBoard(bid, {
        'cols': [for (final c in cols) c.toMap()]
      });

  Future<void> setLabels(String bid, List<BoardLabel> labels) =>
      updateBoard(bid, {
        'lbs': [for (final l in labels) l.toMap()]
      });

  /// Удаляет колонку, переносит её карточки в [moveTo] (в конец).
  Future<void> deleteColumn(
      Board board, List<TaskCard> all, String colId, String moveTo) {
    final cols = board.columns.where((c) => c.id != colId).toList();
    final moving = cardsIn(all, colId);
    final target = cardsIn(all, moveTo);
    var order = target.isEmpty ? orderStep : target.last.order + orderStep;
    final toDone = board.isDoneColumn(moveTo);
    final b = _db.batch()
      ..update(_boards.doc(board.id), {
        'cols': [for (final c in cols) c.toMap()],
        'up': _ts(),
      });
    for (final c in moving) {
      b.update(_cards(board.id).doc(c.id), {
        'col': moveTo,
        'o': order,
        'dn': toDone ? (c.doneAt == null ? _ts() : c.doneAt) : null,
        'up': _ts(),
      });
      order += orderStep;
    }
    return _guard(() => b.commit());
  }

  // ------------------------------------------------------------ участники

  Future<void> _setMembers(Board b, Map<String, BoardRole> roles,
      {String? owner}) {
    final ow = owner ?? b.owner;
    final mb = [ow, ...roles.keys.where((u) => u != ow)];
    return updateBoard(b.id, {
      'ow': ow,
      'mb': mb,
      'rl': {for (final e in roles.entries) e.key: e.value.name},
    });
  }

  Map<String, BoardRole> _roles(Board b) => {
        for (final u in b.members) u: b.roleOf(u) ?? BoardRole.viewer,
      };

  Future<void> addMember(Board b, String uid, BoardRole role) {
    if (b.members.contains(uid)) return setRole(b, uid, role);
    if (b.members.length >= maxMembers) {
      return Future.error(BoardException('limit'));
    }
    return _setMembers(b, {..._roles(b), uid: role});
  }

  Future<void> setRole(Board b, String uid, BoardRole role) {
    if (uid == b.owner || role == BoardRole.owner) {
      return Future.error(BoardException('rules'));
    }
    return _setMembers(b, {..._roles(b), uid: role});
  }

  Future<void> removeMember(Board b, String uid) {
    if (uid == b.owner) return Future.error(BoardException('rules'));
    return _setMembers(b, {..._roles(b)}..remove(uid));
  }

  /// Выйти из доски (не владельцу).
  Future<void> leave(Board b) {
    final uid = me;
    if (uid == b.owner) return Future.error(BoardException('rules'));
    final roles = _roles(b)..remove(uid);
    return _guard(() => _boards.doc(b.id).update({
          'mb': [
            for (final u in b.members)
              if (u != uid) u
          ],
          'rl': {for (final e in roles.entries) e.key: e.value.name},
          'up': _ts(),
        }));
  }

  /// Передать владение участнику [to]; прежний владелец становится редактором.
  Future<void> transferOwnership(Board b, String to) {
    if (!b.members.contains(to) || to == b.owner) {
      return Future.error(BoardException('rules'));
    }
    final roles = _roles(b)
      ..[b.owner] = BoardRole.editor
      ..[to] = BoardRole.owner;
    return _setMembers(b, roles, owner: to);
  }

  /// Удаляет доску вместе с карточками, комментариями и историей.
  Future<void> deleteBoard(String bid) => _guard(() async {
        Future<void> wipe(Query<Map<String, dynamic>> q,
            [Future<void> Function(DocumentReference<Map<String, dynamic>>)?
                before]) async {
          while (true) {
            final s = await q.limit(200).get();
            if (s.docs.isEmpty) break;
            for (final d in s.docs) {
              if (before != null) await before(d.reference);
            }
            final b = _db.batch();
            for (final d in s.docs) {
              b.delete(d.reference);
            }
            await b.commit();
          }
        }

        await wipe(_cards(bid), (card) => wipe(card.collection('comments')));
        await wipe(_activity(bid));
        await _boards.doc(bid).delete();
      });

  // ------------------------------------------------------------- карточки

  /// Добавляет карточку в конец колонки. Возвращает её id сразу;
  /// запись завершится в done.
  ({String id, Future<void> done}) addCard(
    Board board,
    List<TaskCard> all,
    String colId,
    String title, {
    DateTime? due,
    List<LinkedGrant> grants = const [],
    List<LinkedPaper> papers = const [],
    List<String> assignees = const [],
  }) {
    final col = cardsIn(all, colId);
    final order = col.isEmpty ? orderStep : col.last.order + orderStep;
    final ref = _cards(board.id).doc();
    final data = _newCard(
      title: title,
      colId: colId,
      order: order,
      due: due,
      grants: grants,
      papers: papers,
      assignees: assignees,
    );
    if (board.isDoneColumn(colId)) data['dn'] = _ts();
    final b = _db.batch()..set(ref, data);
    _log(b, board.id, 'create', ref.id, title, to: board.column(colId)?.name);
    return (id: ref.id, done: _commit(b));
  }

  /// Изменяет поля карточки ([data] — поля Firestore: t, d, due, p, lb, as,
  /// ck, pp, gr).
  Future<void> updateCard(String bid, String cid, Map<String, Object?> data) =>
      _guard(() => _cards(bid).doc(cid).update({...data, 'up': _ts()}));

  Future<void> setDue(String bid, String cid, DateTime? due) => updateCard(
      bid, cid, {'due': due == null ? null : Timestamp.fromDate(due)});

  Future<void> setChecklist(
          String bid, String cid, List<ChecklistItem> items) =>
      updateCard(bid, cid, {
        'ck': [for (final i in items) i.toMap()]
      });

  Future<void> setPapers(String bid, String cid, List<LinkedPaper> papers) =>
      updateCard(bid, cid, {
        'pp': [for (final p in papers) p.toMap()]
      });

  Future<void> setGrants(String bid, String cid, List<LinkedGrant> grants) =>
      updateCard(bid, cid, {
        'gr': [for (final g in grants) g.toMap()]
      });

  /// Перемещает карточку в колонку [colId] на позицию [index].
  /// Если места между соседями не осталось — перенумеровывает колонку.
  Future<void> moveCard(
      Board board, List<TaskCard> all, TaskCard card, String colId, int index) {
    final order = orderForMove(all, card, colId, index);
    final toDone = board.isDoneColumn(colId);
    final wasDone = board.isDoneColumn(card.column);
    final b = _db.batch();
    final doneValue =
        toDone ? (wasDone && card.doneAt != null ? card.doneAt : _ts()) : null;
    if (order != null) {
      b.update(_cards(board.id).doc(card.id), {
        'col': colId,
        'o': order,
        'dn': doneValue,
        'up': _ts(),
      });
    } else {
      final orders = renumberWithInsert(all, card, colId, index);
      for (final e in orders.entries) {
        b.update(_cards(board.id).doc(e.key), {
          'o': e.value,
          if (e.key == card.id) ...{'col': colId, 'dn': doneValue},
          'up': _ts(),
        });
      }
    }
    if (colId != card.column) {
      _log(b, board.id, toDone ? 'done' : 'move', card.id, card.title,
          from: board.column(card.column)?.name, to: board.column(colId)?.name);
    }
    return _commit(b);
  }

  /// Удаляет карточку вместе с комментариями.
  Future<void> deleteCard(Board board, TaskCard card) => _guard(() async {
        final cm =
            await _cards(board.id).doc(card.id).collection('comments').get();
        final b = _db.batch();
        for (final d in cm.docs) {
          b.delete(d.reference);
        }
        b.delete(_cards(board.id).doc(card.id));
        _log(b, board.id, 'delete', card.id, card.title,
            from: board.column(card.column)?.name);
        await b.commit();
      });

  Future<void> addComment(Board board, TaskCard card, String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > maxComment) {
      return Future.error(BoardException('other'));
    }
    final b = _db.batch()
      ..set(_cards(board.id).doc(card.id).collection('comments').doc(), {
        'by': me,
        't': t,
        'at': _ts(),
      });
    _log(b, board.id, 'comment', card.id, card.title);
    return _commit(b);
  }

  Future<void> deleteComment(String bid, String cid, String commentId) =>
      _guard(() =>
          _cards(bid).doc(cid).collection('comments').doc(commentId).delete());

  void _log(
      WriteBatch b, String bid, String kind, String cardId, String cardTitle,
      {String? from, String? to}) {
    String cut(String s, int n) => s.length > n ? s.substring(0, n) : s;
    b.set(_activity(bid).doc(), {
      'by': me,
      'k': kind,
      'card': cardId,
      'ct': cut(cardTitle, 200),
      'from': cut(from ?? '', 80),
      'to': cut(to ?? '', 80),
      'at': _ts(),
    });
  }

  Future<void> _commit(WriteBatch b) => _guard(() => b.commit());

  // ------------------------------------------------- «Удалить мои данные»

  /// Удаляет мои личные доски и выходит из общих. Общие доски, которыми я
  /// владею, обрабатываются по [decide]: передать права (uid нового
  /// владельца) или удалить (null).
  Future<void> deleteAllMine(
      Future<String?> Function(Board board) decide) async {
    final uid = me;
    final s = await _guard(() => _boards.where('mb', arrayContains: uid).get());
    for (final d in s.docs) {
      final b = Board.fromMap(d.id, d.data());
      if (!b.isOwner(uid)) {
        await leave(b);
      } else if (!b.isShared) {
        await deleteBoard(b.id);
      } else {
        final to = await decide(b);
        if (to == null) {
          await deleteBoard(b.id);
        } else {
          await transferOwnership(b, to);
          final updated =
              Board.fromMap(b.id, (await _boards.doc(b.id).get()).data() ?? {});
          await leave(updated);
        }
      }
    }
  }
}
