import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/chat.dart';
import 'package:scinode/screens/chat_screen.dart';
import 'package:scinode/services/chat_service.dart';
import 'package:scinode/strings.dart';

const alice = 'alice', bob = 'bob';

Map<String, dynamic> conv({
  String status = 'pending',
  String requester = alice,
  String lastFrom = alice,
  DateTime? lastAt,
  Map<String, DateTime> lastRead = const {},
  List<String> blockedBy = const [],
}) =>
    {
      'members': [alice, bob],
      'status': status,
      'requester': requester,
      'first': 'm1',
      'updated': lastAt,
      'last': {'t': 'Привет', 'from': lastFrom, 'at': lastAt},
      'lastRead': lastRead,
      'blockedBy': blockedBy,
    };

Future<void> addProfile(FakeFirebaseFirestore db, String uid, String name) =>
    db.collection('profiles').doc(uid).set({
      'n': name,
      'r': 'researcher',
      'o': 'NUUz',
      'c': 'UZ',
      'b': '',
      'orc': '',
      'oa': '',
      'oan': '',
      'tg': [],
      'tn': [],
      'u': Timestamp.now(),
    });

void main() {
  final t0 = DateTime(2026, 11, 5, 10, 0);

  group('Модель переписки', () {
    test('id переписки одинаковый для пары в любом порядке', () {
      expect(conversationId(bob, alice), 'alice_bob');
      expect(conversationId(alice, bob), 'alice_bob');
    });

    test('разбор и собеседник', () {
      final c = Conversation.fromMap('alice_bob', conv(lastAt: t0));
      expect(c.other(alice), bob);
      expect(c.other(bob), alice);
      expect(c.status, ChatStatus.pending);
      expect(c.last!.text, 'Привет');
      expect(c.last!.at, t0);
    });

    test('непрочитанное и входящий запрос', () {
      final c = Conversation.fromMap('x', conv(lastAt: t0));
      expect(c.isUnread(bob), isTrue);
      expect(c.isUnread(alice), isFalse); // своё сообщение
      expect(c.isIncomingRequest(bob), isTrue);
      expect(c.isIncomingRequest(alice), isFalse);
      final read =
          Conversation.fromMap('x', conv(lastAt: t0, lastRead: {bob: t0}));
      expect(read.isUnread(bob), isFalse);
      final newer = Conversation.fromMap(
          'x',
          conv(
              lastAt: t0.add(const Duration(minutes: 1)), lastRead: {bob: t0}));
      expect(newer.isUnread(bob), isTrue);
    });

    test('писать можно только в принятую и не заблокированную переписку', () {
      expect(Conversation.fromMap('x', conv()).canSend(alice), isFalse);
      expect(Conversation.fromMap('x', conv(status: 'accepted')).canSend(alice),
          isTrue);
      expect(
          Conversation.fromMap('x', conv(status: 'accepted', blockedBy: [bob]))
              .canSend(alice),
          isFalse);
      expect(Conversation.fromMap('x', conv(status: 'declined')).canSend(bob),
          isFalse);
    });

    test('статус «прочитано» для моих сообщений', () {
      final c = Conversation.fromMap('x', conv(lastRead: {bob: t0}));
      expect(c.readByOther(alice, t0), isTrue);
      expect(c.readByOther(alice, t0.subtract(const Duration(minutes: 5))),
          isTrue);
      expect(c.readByOther(alice, t0.add(const Duration(seconds: 1))), isFalse);
      expect(c.readByOther(alice, null), isFalse);
    });

    test('проверка текста и краткая копия', () {
      expect(validateMessage('  '), 'empty');
      expect(validateMessage('x' * 2001), 'long');
      expect(validateMessage(' ${'x' * 2000} '), isNull);
      expect(previewOf('  Привет,\n\nколлега  '), 'Привет, коллега');
      expect(previewOf('я' * 500).length, 200);
    });

    test('время сообщения', () {
      final now = DateTime(2026, 11, 5, 18, 30);
      String f(DateTime d) => formatChatTime(d, now, yesterday: 'Вчера');
      expect(f(DateTime(2026, 11, 5, 9, 7)), '09:07');
      expect(f(DateTime(2026, 11, 4, 23, 59)), 'Вчера');
      expect(f(DateTime(2026, 3, 1)), '01.03');
      expect(f(DateTime(2025, 12, 31)), '31.12.2025');
    });

    test('сортировка: входящие запросы сверху, затем свежие', () {
      final a = Conversation.fromMap('a',
          conv(status: 'accepted', lastAt: t0.add(const Duration(hours: 2))));
      final b = Conversation.fromMap('b', conv(lastAt: t0)); // запрос для bob
      final c = Conversation.fromMap('c',
          conv(status: 'accepted', lastAt: t0.add(const Duration(hours: 1))));
      final sorted = sortConversations([c, a, b], bob);
      expect(sorted.map((e) => e.id), ['b', 'a', 'c']);
      expect(attentionCount([a, b, c], bob), 3);
      expect(attentionCount([a, b, c], alice), 0);
    });
  });

  group('ChatService (поддельный Firestore)', () {
    late FakeFirebaseFirestore db;
    ChatService svc(String uid) => ChatService(db: db, uid: () => uid);

    setUp(() async {
      db = FakeFirebaseFirestore();
      await addProfile(db, alice, 'Alice');
      await addProfile(db, bob, 'Bob');
    });

    test('первое сообщение создаёт запрос и одно сообщение', () async {
      final cid = await svc(alice).start(bob, '  Здравствуйте!  ');
      expect(cid, 'alice_bob');
      final c = (await db.collection('conversations').doc(cid).get()).data()!;
      expect(c['status'], 'pending');
      expect(c['requester'], alice);
      expect(c['members'], [alice, bob]);
      expect(c['blockedBy'], isEmpty);
      final msgs = await db
          .collection('conversations')
          .doc(cid)
          .collection('messages')
          .get();
      expect(msgs.docs.length, 1);
      expect(msgs.docs.single.id, c['first']);
      expect(msgs.docs.single.data()['text'], 'Здравствуйте!');
      expect((c['last'] as Map)['t'], 'Здравствуйте!');
    });

    test('пустое и слишком длинное сообщение не отправляются', () async {
      expect(() => svc(alice).start(bob, '   '),
          throwsA(isA<ChatException>().having((e) => e.kind, 'kind', 'empty')));
      expect(() => svc(alice).send('alice_bob', 'x' * 2001),
          throwsA(isA<ChatException>().having((e) => e.kind, 'kind', 'long')));
    });

    test('принять, переписываться, прочитать, заблокировать', () async {
      final cid = await svc(alice).start(bob, 'Привет');
      await svc(bob).accept(cid);
      await svc(bob).send(cid, 'Добрый день');
      var c = Conversation.fromMap(
          cid, (await db.collection('conversations').doc(cid).get()).data()!);
      expect(c.status, ChatStatus.accepted);
      expect(c.last!.from, bob);
      expect(c.isUnread(alice), isTrue);

      await svc(alice).markRead(c);
      c = Conversation.fromMap(
          cid, (await db.collection('conversations').doc(cid).get()).data()!);
      expect(c.isUnread(alice), isFalse);

      await svc(alice).block(cid);
      c = Conversation.fromMap(
          cid, (await db.collection('conversations').doc(cid).get()).data()!);
      expect(c.blockedByMe(alice), isTrue);
      expect(c.canSend(bob), isFalse);
      await svc(alice).unblock(cid);
      c = Conversation.fromMap(
          cid, (await db.collection('conversations').doc(cid).get()).data()!);
      expect(c.isBlocked, isFalse);
    });

    test('повторный «Написать» не создаёт вторую переписку', () async {
      await svc(alice).start(bob, 'Первое');
      await svc(bob).accept('alice_bob');
      await svc(alice).start(bob, 'Второе');
      expect((await db.collection('conversations').get()).docs.length, 1);
      final msgs = await db
          .collection('conversations')
          .doc('alice_bob')
          .collection('messages')
          .get();
      expect(msgs.docs.length, 2);
    });

    test('список переписок и сообщения по порядку', () async {
      await svc(alice).start(bob, 'Привет');
      await svc(bob).accept('alice_bob');
      await svc(bob).send('alice_bob', 'Ответ');
      final list = await svc(bob).conversations().first;
      expect(list.single.id, 'alice_bob');
      final msgs = await svc(bob).messages('alice_bob').first;
      expect(msgs.map((m) => m.text), ['Привет', 'Ответ']);
    });

    test('жалоба сохраняет текст и автора', () async {
      await svc(alice).start(bob, 'Спам');
      final m = (await svc(bob).messages('alice_bob').first).single;
      await svc(bob).report('alice_bob', m, 'реклама');
      final r = (await db.collection('reports').get()).docs.single.data();
      expect(r['reporter'], bob);
      expect(r['author'], alice);
      expect(r['text'], 'Спам');
      expect(r['reason'], 'реклама');
    });

    test('удаление моих переписок вместе с сообщениями', () async {
      await addProfile(db, 'carol', 'Carol');
      await svc(alice).start(bob, 'Привет');
      await svc(alice).start('carol', 'Привет');
      await svc('bob').start('carol', 'Чужая переписка');
      final n = await svc(alice).deleteAllMine();
      expect(n, 2);
      final left = await db.collection('conversations').get();
      expect(left.docs.map((d) => d.id), ['bob_carol']);
      final orphan = await db
          .collection('conversations')
          .doc('alice_bob')
          .collection('messages')
          .get();
      expect(orphan.docs, isEmpty);
    });

    test('профиль собеседника и проверка своего профиля', () async {
      expect((await svc(alice).profileOf(bob))!.name, 'Bob');
      expect(await svc(alice).profileOf('ghost'), isNull);
      expect(await svc(alice).myProfilePublished(), isTrue);
      expect(await svc('ghost').myProfilePublished(), isFalse);
    });
  });

  group('Экран переписки', () {
    late FakeFirebaseFirestore db;

    setUp(() async {
      Strings.instance.lang = 'ru';
      db = FakeFirebaseFirestore();
      await addProfile(db, alice, 'Alice');
      await addProfile(db, bob, 'Bob');
    });

    Future<void> open(
        WidgetTester tester, String me, String other, String name) async {
      await tester.pumpWidget(MaterialApp(
        home: ChatScreen(
          otherUid: other,
          otherName: name,
          service: ChatService(db: db, uid: () => me),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('новая переписка: подсказка, отправка, ожидание ответа',
        (tester) async {
      await open(tester, alice, bob, 'Bob');
      expect(find.textContaining('Первое сообщение станет запросом'),
          findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Здравствуйте, коллега!');
      await tester.pump();
      await tester.tap(find.byTooltip('Отправить'));
      await tester.pumpAndSettle();
      expect(find.text('Здравствуйте, коллега!'), findsOneWidget);
      expect(find.textContaining('Запрос отправлен'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('получатель видит запрос, принимает и может ответить',
        (tester) async {
      await ChatService(db: db, uid: () => alice).start(bob, 'Привет, Bob');
      await open(tester, bob, alice, 'Alice');
      expect(find.text('Привет, Bob'), findsOneWidget);
      expect(
          find.textContaining('хочет начать с вами переписку'), findsOneWidget);
      await tester.tap(find.text('Принять'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      // Входящее сообщение отмечено прочитанным.
      final c = Conversation.fromMap(
          'alice_bob',
          (await db.collection('conversations').doc('alice_bob').get())
              .data()!);
      expect(c.isUnread(bob), isFalse);
    });

    testWidgets('без опубликованного профиля писать нельзя', (tester) async {
      await open(tester, 'ghost', bob, 'Bob');
      expect(find.textContaining('опубликуйте свой профиль'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('список переписок: запросы отдельно', (tester) async {
      await ChatService(db: db, uid: () => alice).start(bob, 'Привет, Bob');
      await tester.pumpWidget(MaterialApp(
        home: ChatListScreen(service: ChatService(db: db, uid: () => bob)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Запросы на переписку'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Привет, Bob'), findsOneWidget);
    });
  });
}
