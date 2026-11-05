import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/board.dart';
import 'package:scinode/services/board_service.dart';

const alice = 'alice', bob = 'bob', carol = 'carol';

TaskCard card(String id, String col, double o,
        {DateTime? due,
        int p = 1,
        List<String> as = const [],
        List<String> lb = const [],
        String t = 'Задача',
        String d = ''}) =>
    TaskCard(
        id: id,
        boardId: 'b',
        title: t,
        description: d,
        column: col,
        order: o,
        due: due,
        priority: p,
        assignees: as,
        labels: lb);

Board board({List<String> mb = const [alice], bool archived = false}) => Board(
      id: 'b',
      name: 'Доска',
      owner: alice,
      members: mb,
      roles: {
        for (final u in mb) u: u == alice ? BoardRole.owner : BoardRole.editor
      },
      columns: const [
        BoardColumn(id: 'todo', name: 'Идеи'),
        BoardColumn(id: 'work', name: 'В работе'),
        BoardColumn(id: 'done', name: 'Готово', done: true),
      ],
      archived: archived,
    );

void main() {
  final now = DateTime(2026, 11, 5, 12);

  group('Порядок карточек', () {
    test('orderBetween', () {
      expect(orderBetween(null, null), orderStep);
      expect(orderBetween(null, 1024), 0);
      expect(orderBetween(1024, null), 2048);
      expect(orderBetween(1024, 2048), 1536);
      expect(orderBetween(1.0, 1.0 + 1e-9), isNull);
    });

    test('cardsIn сортирует по порядку', () {
      final all = [
        card('a', 'todo', 3),
        card('b', 'todo', 1),
        card('c', 'work', 2)
      ];
      expect(cardsIn(all, 'todo').map((c) => c.id), ['b', 'a']);
    });

    test('перемещение в начало, середину и конец другой колонки', () {
      final all = [
        card('x', 'todo', 1024),
        card('a', 'work', 1024),
        card('b', 'work', 2048),
      ];
      final x = all.first;
      expect(orderForMove(all, x, 'work', 0), 0);
      expect(orderForMove(all, x, 'work', 1), 1536);
      expect(orderForMove(all, x, 'work', 2), 3072);
      expect(orderForMove(all, x, 'work', 99), 3072); // за пределами — в конец
      expect(orderForMove(all, x, 'done', 0), orderStep); // пустая колонка
    });

    test('перемещение внутри колонки не учитывает саму карточку', () {
      final all = [
        card('a', 'todo', 1024),
        card('b', 'todo', 2048),
        card('c', 'todo', 3072)
      ];
      // Переносим «a» после «b» (позиция 1 среди b, c).
      expect(orderForMove(all, all[0], 'todo', 1), 2560);
    });

    test('перенумерация, когда места не осталось', () {
      final all = [
        card('a', 'todo', 1.0),
        card('b', 'todo', 1.0 + 1e-9),
        card('x', 'work', 5)
      ];
      expect(orderForMove(all, all[2], 'todo', 1), isNull);
      final r = renumberWithInsert(all, all[2], 'todo', 1);
      expect(r, {'a': 1024.0, 'x': 2048.0, 'b': 3072.0});
    });
  });

  group('Сроки', () {
    test('состояния', () {
      expect(dueState(null, now), DueState.none);
      expect(dueState(DateTime(2026, 11, 4), now), DueState.overdue);
      expect(dueState(DateTime(2026, 11, 5, 23), now), DueState.today);
      expect(dueState(DateTime(2026, 11, 12), now), DueState.week);
      expect(dueState(DateTime(2026, 11, 13), now), DueState.later);
      expect(dueState(DateTime(2026, 11, 1), now, done: true), DueState.done);
    });
  });

  group('Фильтры', () {
    final cards = [
      card('1', 'todo', 1,
          t: 'Обзор литературы',
          as: [alice],
          lb: ['l1'],
          p: 3,
          due: DateTime(2026, 11, 3)),
      card('2', 'todo', 2,
          t: 'Бюджет',
          d: 'посчитать гранты',
          as: [bob],
          due: DateTime(2026, 11, 10)),
      card('3', 'work', 3, t: 'Эксперимент'),
    ];
    List<String> ids(CardFilter f) => [
          for (final c in cards)
            if (f.matches(c, now, done: false)) c.id
        ];

    test('пустой фильтр', () {
      expect(const CardFilter().isEmpty, isTrue);
      expect(ids(const CardFilter()), ['1', '2', '3']);
    });
    test('поиск по названию и описанию', () {
      expect(ids(const CardFilter(query: 'обзор')), ['1']);
      expect(ids(const CardFilter(query: 'ГРАНТЫ')), ['2']);
    });
    test('исполнитель и «без исполнителя»', () {
      expect(ids(const CardFilter(assignee: bob)), ['2']);
      expect(ids(const CardFilter(assignee: '')), ['3']);
    });
    test('метка и приоритет', () {
      expect(ids(const CardFilter(label: 'l1')), ['1']);
      expect(ids(const CardFilter(priority: 3)), ['1']);
    });
    test('сроки: просрочено, неделя, без срока', () {
      expect(ids(const CardFilter(due: DueFilter.overdue)), ['1']);
      expect(ids(const CardFilter(due: DueFilter.week)), ['1', '2']);
      expect(ids(const CardFilter(due: DueFilter.none)), ['3']);
    });
    test('выполненная карточка не считается просроченной', () {
      expect(
          const CardFilter(due: DueFilter.overdue)
              .matches(cards[0], now, done: true),
          isFalse);
    });
    test('copyWith сбрасывает значения', () {
      const f = CardFilter(assignee: bob, priority: 2);
      final g = f.copyWith(assignee: () => null);
      expect(g.assignee, isNull);
      expect(g.priority, 2);
    });
  });

  group('Статистика и мои задачи', () {
    test('BoardStats', () {
      final b = board(mb: [alice, bob]);
      final cards = [
        card('1', 'todo', 1, as: [alice], due: DateTime(2026, 11, 1)),
        card('2', 'work', 1, as: [alice, bob]),
        card('3', 'work', 2),
        card('4', 'done', 1, as: [bob], due: DateTime(2026, 11, 1)),
      ];
      final s = BoardStats.of(b, cards, now);
      expect(s.total, 4);
      expect(s.done, 1);
      expect(s.open, 3);
      expect(s.overdue, 1); // выполненная просроченной не считается
      expect(s.percent, 25);
      expect(s.perColumn, {'todo': 1, 'work': 2, 'done': 1});
      expect(s.openPerMember, {alice: 2, bob: 1, '': 1});
    });

    test('isMyTask: личная доска — все задачи, общая — назначенные', () {
      expect(isMyTask(board(), card('1', 'todo', 1), alice), isTrue);
      final shared = board(mb: [alice, bob]);
      expect(isMyTask(shared, card('1', 'todo', 1), alice), isFalse);
      expect(
          isMyTask(shared, card('1', 'todo', 1, as: [alice]), alice), isTrue);
    });

    test('группировка по срокам, выполненные и архив пропускаются', () {
      final b = board();
      final tasks = [
        MyTask(b, card('o', 'todo', 1, due: DateTime(2026, 11, 2))),
        MyTask(b, card('t', 'todo', 1, due: DateTime(2026, 11, 5))),
        MyTask(b, card('w2', 'todo', 1, due: DateTime(2026, 11, 9), p: 0)),
        MyTask(b, card('w1', 'todo', 1, due: DateTime(2026, 11, 7))),
        MyTask(b, card('l', 'todo', 1, due: DateTime(2027, 1, 1))),
        MyTask(b, card('n', 'todo', 1)),
        MyTask(b, card('d', 'done', 1, due: DateTime(2026, 11, 1))),
        MyTask(board(archived: true), card('a', 'todo', 1)),
      ];
      final g = groupMyTasks(tasks, now);
      expect(g[TaskGroup.overdue]!.map((t) => t.card.id), ['o']);
      expect(g[TaskGroup.today]!.map((t) => t.card.id), ['t']);
      expect(g[TaskGroup.week]!.map((t) => t.card.id), ['w1', 'w2']);
      expect(g[TaskGroup.later]!.map((t) => t.card.id), ['l']);
      expect(g[TaskGroup.noDate]!.map((t) => t.card.id), ['n']);
    });
  });

  group('Разбор данных', () {
    test('Board.fromMap: роли, колонки, защита от мусора', () {
      final b = Board.fromMap('b1', {
        'n': 'Диссертация',
        'ow': alice,
        'mb': [alice, bob],
        'rl': {alice: 'owner', bob: 'viewer', 'x': 'hacker'},
        'cols': [
          {'id': 'c1', 'n': 'Идеи', 'lim': 3},
          {'n': 'без id'},
          'мусор'
        ],
        'lbs': [
          {'id': 'l1', 'n': 'Срочно', 'c': 99}
        ],
        'c': 50,
        'ic': 'неизвестная',
        'ar': true,
      });
      expect(b.roleOf(alice), BoardRole.owner);
      expect(b.roleOf(bob), BoardRole.viewer);
      expect(b.roleOf('x'), isNull);
      expect(b.canEdit(bob), isFalse);
      expect(b.columns.single.limit, 3);
      expect(b.labels.single.color, boardColors.length - 1);
      expect(b.color, boardColors.length - 1);
      expect(b.icon, 'science');
      expect(b.archived, isTrue);
    });

    test('LinkedGrant не принимает опасные ссылки', () {
      final g = LinkedGrant.fromMap({'id': '1', 'url': 'javascript:alert(1)'});
      expect(g!.url, '');
      final ok = LinkedGrant.fromMap(
          {'id': '2', 'url': 'https://www.grants.gov/x', 'dl': 0});
      expect(ok!.url, 'https://www.grants.gov/x');
      expect(ok.deadline, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('шаблоны: последняя колонка — «Готово», карточки в пределах', () {
      for (final t in boardTemplates) {
        expect(t.columns.length, inInclusiveRange(2, maxColumns));
        for (final (_, col) in t.cards) {
          expect(col, lessThan(t.columns.length));
        }
      }
      expect(templateOf('нет такого').key, 'empty');
    });
  });

  group('BoardService (поддельный Firestore)', () {
    late FakeFirebaseFirestore db;
    BoardService svc(String uid) =>
        BoardService(db: db, uid: () => uid, rnd: Random(1));

    setUp(() => db = FakeFirebaseFirestore());

    Future<Board> getBoard(String id) async => Board.fromMap(
        id, (await db.collection('boards').doc(id).get()).data()!);
    Future<List<TaskCard>> getCards(String id) async => [
          for (final d in (await db
                  .collection('boards')
                  .doc(id)
                  .collection('cards')
                  .get())
              .docs)
            TaskCard.fromMap(d.id, id, d.data()),
        ];

    test('создание доски по шаблону', () async {
      final r = svc(alice).createBoard(
        name: 'Статья',
        template: 'paper',
        color: 1,
        icon: 'article',
        columns: ['Идеи', 'Черновик', 'Готово'],
        cards: [('Тема', 0), ('Журнал', 0), ('Текст', 1)],
      );
      await r.done;
      final b = await getBoard(r.id);
      expect(b.owner, alice);
      expect(b.members, [alice]);
      expect(b.columns.map((c) => c.name), ['Идеи', 'Черновик', 'Готово']);
      expect(b.columns.last.done, isTrue);
      expect(b.columns.first.done, isFalse);
      final cards = await getCards(r.id);
      expect(cards.length, 3);
      expect(cardsIn(cards, b.columns[0].id).map((c) => c.title),
          ['Тема', 'Журнал']);
    });

    test('доска из гранта: дедлайн и ссылка только в карточке подачи',
        () async {
      final g = LinkedGrant(
          source: 'grantsGov',
          id: '1',
          number: 'G-1',
          title: 'Water',
          url: 'https://www.grants.gov/search-results-detail/1',
          deadline: DateTime(2026, 12, 1));
      final r = svc(alice).createBoard(
        name: 'Заявка',
        template: 'grant',
        color: 3,
        icon: 'payments',
        columns: ['Подготовка', 'Подано'],
        cards: [('Условия', 0)],
        extra: [
          NewCard(title: 'Подать', column: 1, due: g.deadline, grants: [g]),
        ],
      );
      await r.done;
      final cards = await getCards(r.id);
      final plain = cards.firstWhere((c) => c.title == 'Условия');
      final submit = cards.firstWhere((c) => c.title == 'Подать');
      expect(plain.due, isNull);
      expect(plain.grants, isEmpty);
      expect(submit.due, DateTime(2026, 12, 1));
      expect(submit.grants.single.number, 'G-1');
      expect(submit.order, greaterThan(plain.order));
    });

    test('добавить, переместить в «Готово» и обратно, история', () async {
      final r = svc(alice).createBoard(
          name: 'Д',
          template: 'empty',
          color: 0,
          icon: 'flag',
          columns: ['A', 'B', 'Готово']);
      await r.done;
      var b = await getBoard(r.id);
      final add =
          svc(alice).addCard(b, const [], b.columns[0].id, ' Задача 1 ');
      await add.done;
      var cards = await getCards(r.id);
      expect(cards.single.title, 'Задача 1');

      await svc(alice).moveCard(b, cards, cards.single, b.columns[2].id, 0);
      cards = await getCards(r.id);
      expect(cards.single.column, b.columns[2].id);
      expect(cards.single.doneAt, isNotNull);

      await svc(alice).moveCard(b, cards, cards.single, b.columns[1].id, 0);
      cards = await getCards(r.id);
      expect(cards.single.doneAt, isNull);

      final act =
          await db.collection('boards').doc(r.id).collection('activity').get();
      expect(act.docs.map((d) => d['k']).toSet(), {'create', 'done', 'move'});
    });

    test('перемещение с перенумерацией колонки', () async {
      final r = svc(alice).createBoard(
          name: 'Д',
          template: 'empty',
          color: 0,
          icon: 'flag',
          columns: ['A', 'Готово']);
      await r.done;
      final b = await getBoard(r.id);
      final col = b.columns[0].id;
      final ref = db.collection('boards').doc(r.id).collection('cards');
      Map<String, dynamic> raw(String t, double o) => {
            't': t,
            'd': '',
            'col': col,
            'o': o,
            'due': null,
            'p': 1,
            'lb': [],
            'as': [],
            'ck': [],
            'pp': [],
            'gr': [],
            'by': alice,
            'dn': null,
          };
      await ref.doc('a').set(raw('a', 1.0));
      await ref.doc('b').set(raw('b', 1.0 + 1e-9));
      await ref.doc('x').set({...raw('x', 5.0), 'col': b.columns[1].id});
      var cards = await getCards(r.id);
      await svc(alice)
          .moveCard(b, cards, cards.firstWhere((c) => c.id == 'x'), col, 1);
      cards = await getCards(r.id);
      expect(cardsIn(cards, col).map((c) => c.id), ['a', 'x', 'b']);
    });

    test('удаление колонки переносит карточки в конец другой', () async {
      final r = svc(alice).createBoard(
          name: 'Д',
          template: 'empty',
          color: 0,
          icon: 'flag',
          columns: ['A', 'B', 'Готово'],
          cards: [('1', 0), ('2', 0), ('3', 1)]);
      await r.done;
      final b = await getBoard(r.id);
      await svc(alice).deleteColumn(
          b, await getCards(r.id), b.columns[0].id, b.columns[1].id);
      final nb = await getBoard(r.id);
      expect(nb.columns.length, 2);
      final cards = await getCards(r.id);
      expect(
          cardsIn(cards, b.columns[1].id).map((c) => c.title), ['3', '1', '2']);
    });

    test('участники: добавить, роль, выйти, передать владение', () async {
      final r = svc(alice).createBoard(
          name: 'Д',
          template: 'lab',
          color: 0,
          icon: 'groups',
          columns: ['A', 'Готово']);
      await r.done;
      var b = await getBoard(r.id);
      await svc(alice).addMember(b, bob, BoardRole.editor);
      b = await getBoard(r.id);
      await svc(alice).addMember(b, carol, BoardRole.viewer);
      b = await getBoard(r.id);
      expect(b.members, [alice, bob, carol]);
      expect(b.roleOf(carol), BoardRole.viewer);
      expect(b.canEdit(carol), isFalse);

      await svc(alice).setRole(b, carol, BoardRole.editor);
      b = await getBoard(r.id);
      expect(b.roleOf(carol), BoardRole.editor);

      await svc(carol).leave(b);
      b = await getBoard(r.id);
      expect(b.members, [alice, bob]);

      expect(() => svc(alice).leave(b), throwsA(isA<BoardException>()));

      await svc(alice).transferOwnership(b, bob);
      b = await getBoard(r.id);
      expect(b.owner, bob);
      expect(b.roleOf(alice), BoardRole.editor);
      expect(b.members.first, bob);
    });

    test('мои задачи: личная доска целиком, общая — только назначенные',
        () async {
      final p = svc(alice).createBoard(
          name: 'Личная',
          template: 'empty',
          color: 0,
          icon: 'flag',
          columns: ['A', 'Готово'],
          cards: [('Своя', 0)]);
      await p.done;
      final s = svc(bob).createBoard(
          name: 'Общая',
          template: 'lab',
          color: 0,
          icon: 'flag',
          columns: ['A', 'Готово']);
      await s.done;
      var sb = await getBoard(s.id);
      await svc(bob).addMember(sb, alice, BoardRole.editor);
      sb = await getBoard(s.id);
      await svc(bob)
          .addCard(sb, const [], sb.columns[0].id, 'Для Алисы',
              assignees: [alice])
          .done;
      await svc(bob)
          .addCard(sb, const [], sb.columns[0].id, 'Для Боба', assignees: [bob])
          .done;

      final tasks = await svc(alice).myTasks().firstWhere((l) => l.length >= 2);
      expect(tasks.map((t) => t.card.title).toSet(), {'Своя', 'Для Алисы'});
    });

    test(
        'удаление моих данных: личные удаляются, из общих выхожу, владение передаю',
        () async {
      final mine = svc(alice).createBoard(
          name: 'Моя',
          template: 'empty',
          color: 0,
          icon: 'flag',
          columns: ['A', 'Готово'],
          cards: [('1', 0)]);
      await mine.done;
      final ownedShared = svc(alice).createBoard(
          name: 'Моя общая',
          template: 'lab',
          color: 0,
          icon: 'flag',
          columns: ['A', 'Готово']);
      await ownedShared.done;
      await svc(alice)
          .addMember(await getBoard(ownedShared.id), bob, BoardRole.editor);
      final other = svc(bob).createBoard(
          name: 'Чужая',
          template: 'lab',
          color: 0,
          icon: 'flag',
          columns: ['A', 'Готово']);
      await other.done;
      await svc(bob)
          .addMember(await getBoard(other.id), alice, BoardRole.viewer);

      final asked = <String>[];
      await svc(alice).deleteAllMine((b) async {
        asked.add(b.name);
        return bob; // передать Бобу
      });
      expect(asked, ['Моя общая']);
      expect(
          (await db.collection('boards').doc(mine.id).get()).exists, isFalse);
      expect(
          (await db.collection('boards').doc(mine.id).collection('cards').get())
              .docs,
          isEmpty);
      final os = await getBoard(ownedShared.id);
      expect(os.owner, bob);
      expect(os.members, [bob]);
      final ot = await getBoard(other.id);
      expect(ot.members, [bob]);
    });

    test('комментарии', () async {
      final r = svc(alice).createBoard(
          name: 'Д',
          template: 'empty',
          color: 0,
          icon: 'flag',
          columns: ['A', 'Готово'],
          cards: [('1', 0)]);
      await r.done;
      final b = await getBoard(r.id);
      final c = (await getCards(r.id)).single;
      await svc(alice).addComment(b, c, '  Отлично  ');
      final list = await svc(alice).comments(r.id, c.id).first;
      expect(list.single.text, 'Отлично');
      expect(() => svc(alice).addComment(b, c, '   '),
          throwsA(isA<BoardException>()));
    });
  });
}
