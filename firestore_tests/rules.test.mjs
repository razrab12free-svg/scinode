// Тесты правил Firestore в эмуляторе: node --test (через firebase emulators:exec).
import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, collection, getDocs,
  query, where, serverTimestamp, arrayUnion, arrayRemove, Timestamp, increment,
} from 'firebase/firestore';

let env;
const A = 'alice', B = 'bob', C = 'carol', NOPROFILE = 'nobody';
const CID = `${A}_${B}`; // alice < bob

const profile = (n) => ({
  n, r: 'researcher', o: 'NUUz', c: 'UZ', b: '', orc: '', oa: '', oan: '',
  tg: ['f31'], tn: ['Physics and Astronomy'], u: serverTimestamp(),
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-scinode',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const u of [A, B, C]) {
      await setDoc(doc(db, 'profiles', u), { ...profile(u), u: Timestamp.now() });
    }
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();

/** Запрос на переписку: переписка + первое сообщение одним пакетом. */
function requestBatch(d, from = A, to = B, text = 'Здравствуйте!') {
  const members = [from, to].sort();
  const cid = members.join('_');
  const b = writeBatch(d);
  const mref = doc(collection(d, 'conversations', cid, 'messages'));
  b.set(doc(d, 'conversations', cid), {
    members, status: 'pending', requester: from, first: mref.id,
    created: serverTimestamp(), updated: serverTimestamp(),
    last: { t: text.slice(0, 200), from, at: serverTimestamp() },
    lastRead: { [from]: serverTimestamp() }, blockedBy: [],
  });
  b.set(mref, { from, text, at: serverTimestamp() });
  return { batch: b, cid, mid: mref.id };
}

function sendBatch(d, cid, from, text) {
  const b = writeBatch(d);
  const mref = doc(collection(d, 'conversations', cid, 'messages'));
  b.set(mref, { from, text, at: serverTimestamp() });
  b.update(doc(d, 'conversations', cid), {
    last: { t: text.slice(0, 200), from, at: serverTimestamp() },
    updated: serverTimestamp(),
  });
  return b;
}

// --------------------------------------------------------------- профили

test('профиль: свой можно, чужой нельзя, лишние поля нельзя', async () => {
  await assertSucceeds(setDoc(doc(db(A), 'profiles', A), profile('Alice')));
  await assertFails(setDoc(doc(db(A), 'profiles', B), profile('Hack')));
  await assertFails(setDoc(doc(db(A), 'profiles', A), { ...profile('A'), admin: true }));
  await assertFails(setDoc(doc(db(A), 'profiles', A), { ...profile('A'), b: 'x'.repeat(401) }));
  await assertFails(setDoc(doc(db(A), 'profiles', A), { ...profile('A'), u: Timestamp.fromMillis(0) }));
  await assertSucceeds(getDoc(doc(db(C), 'profiles', A)));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'profiles', A)));
  await assertSucceeds(deleteDoc(doc(db(A), 'profiles', A)));
});

// ------------------------------------------------------------- переписка

test('запрос на переписку создаётся одним пакетом', async () => {
  const { batch } = requestBatch(db(A));
  await assertSucceeds(batch.commit());
});

test('нельзя написать тому, у кого нет профиля, и без своего профиля', async () => {
  await assertFails(requestBatch(db(A), A, NOPROFILE).batch.commit());
  await assertFails(requestBatch(db(NOPROFILE), NOPROFILE, A).batch.commit());
});

test('нельзя создать переписку за другого или с неправильным id', async () => {
  await assertFails(requestBatch(db(C), A, B).batch.commit());
  const d = db(A);
  await assertFails(setDoc(doc(d, 'conversations', 'bob_alice'), {
    members: [A, B], status: 'pending', requester: A, first: 'x',
    created: serverTimestamp(), updated: serverTimestamp(),
    last: { t: 'hi', from: A, at: serverTimestamp() },
    lastRead: { [A]: serverTimestamp() }, blockedBy: [],
  }));
});

test('до принятия — только одно сообщение от автора запроса', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await assertFails(sendBatch(db(A), cid, A, 'Второе').commit());
  await assertFails(sendBatch(db(B), cid, B, 'Ответ до принятия').commit());
});

test('получатель принимает запрос, после этого оба пишут', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await assertFails(updateDoc(doc(db(A), 'conversations', cid), { status: 'accepted' }));
  await assertSucceeds(updateDoc(doc(db(B), 'conversations', cid), { status: 'accepted' }));
  await assertSucceeds(sendBatch(db(B), cid, B, 'Добрый день').commit());
  await assertSucceeds(sendBatch(db(A), cid, A, 'Спасибо').commit());
});

test('отклонённый запрос: писать нельзя, статус больше не меняется', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await assertSucceeds(updateDoc(doc(db(B), 'conversations', cid), { status: 'declined' }));
  await assertFails(sendBatch(db(A), cid, A, 'Ну пожалуйста').commit());
  await assertFails(updateDoc(doc(db(B), 'conversations', cid), { status: 'accepted' }));
});

test('посторонний не читает и не пишет', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await assertFails(getDoc(doc(db(C), 'conversations', cid)));
  await assertFails(getDocs(collection(db(C), 'conversations', cid, 'messages')));
  await assertFails(sendBatch(db(C), cid, C, 'spam').commit());
  await assertSucceeds(getDocs(collection(db(B), 'conversations', cid, 'messages')));
});

test('проверить, есть ли переписка, можно только для своей пары', async () => {
  await assertSucceeds(getDoc(doc(db(A), 'conversations', CID)));
  await assertFails(getDoc(doc(db(C), 'conversations', CID)));
});

test('список своих переписок по members', async () => {
  await requestBatch(db(A)).batch.commit();
  await assertSucceeds(getDocs(query(collection(db(B), 'conversations'),
    where('members', 'array-contains', B))));
  await assertFails(getDocs(collection(db(B), 'conversations')));
});

test('ограничения сообщения: длина, автор, время, без правок', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await updateDoc(doc(db(B), 'conversations', cid), { status: 'accepted' });
  const d = db(A);
  await assertFails(sendBatch(d, cid, A, 'x'.repeat(2001)).commit());
  await assertFails(sendBatch(d, cid, A, '').commit());
  await assertFails(sendBatch(d, cid, B, 'от чужого имени').commit());
  const ref = doc(collection(d, 'conversations', cid, 'messages'));
  await assertFails(setDoc(ref, { from: A, text: 'old', at: Timestamp.fromMillis(0) }));
  await assertSucceeds(sendBatch(d, cid, A, 'x'.repeat(2000)).commit());
  const ok = doc(collection(d, 'conversations', cid, 'messages'));
  await assertSucceeds(setDoc(ok, { from: A, text: 'hi', at: serverTimestamp() }));
  await assertFails(updateDoc(ok, { text: 'edited' }));
});

test('прочитано: каждый отмечает только себя', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await assertSucceeds(updateDoc(doc(db(B), 'conversations', cid), { [`lastRead.${B}`]: serverTimestamp() }));
  await assertFails(updateDoc(doc(db(B), 'conversations', cid), { [`lastRead.${A}`]: serverTimestamp() }));
});

test('блокировка: себя добавить и убрать можно, писать при блокировке нельзя', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await updateDoc(doc(db(B), 'conversations', cid), { status: 'accepted' });
  await assertFails(updateDoc(doc(db(A), 'conversations', cid), { blockedBy: arrayUnion(B) }));
  await assertSucceeds(updateDoc(doc(db(B), 'conversations', cid), { blockedBy: arrayUnion(B) }));
  await assertFails(sendBatch(db(A), cid, A, 'привет').commit());
  await assertFails(sendBatch(db(B), cid, B, 'привет').commit());
  await assertFails(updateDoc(doc(db(A), 'conversations', cid), { blockedBy: arrayRemove(B) }));
  await assertSucceeds(updateDoc(doc(db(B), 'conversations', cid), { blockedBy: arrayRemove(B) }));
  await assertSucceeds(sendBatch(db(A), cid, A, 'снова').commit());
});

test('нельзя подменить участников, автора запроса или последнее сообщение', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await assertFails(updateDoc(doc(db(A), 'conversations', cid), { members: [A, C] }));
  await assertFails(updateDoc(doc(db(B), 'conversations', cid), { requester: B }));
  await assertFails(updateDoc(doc(db(B), 'conversations', cid), {
    last: { t: 'fake', from: A, at: serverTimestamp() }, updated: serverTimestamp(),
  }));
});

test('жалоба: участник может, посторонний нет, читать нельзя', async () => {
  const { batch, cid, mid } = requestBatch(db(A));
  await batch.commit();
  const rep = (who) => ({ reporter: who, cid, mid, author: A, text: 'Здравствуйте!', reason: 'spam', at: serverTimestamp() });
  await assertSucceeds(setDoc(doc(collection(db(B), 'reports')), rep(B)));
  await assertFails(setDoc(doc(collection(db(C), 'reports')), rep(C)));
  await assertFails(setDoc(doc(collection(db(B), 'reports')), rep(A)));
  await assertFails(getDocs(collection(db(B), 'reports')));
});

test('удаление моих данных: сообщения, переписка, профиль', async () => {
  const { batch, cid } = requestBatch(db(A));
  await batch.commit();
  await updateDoc(doc(db(B), 'conversations', cid), { status: 'accepted' });
  await sendBatch(db(B), cid, B, 'ответ').commit();
  const msgs = await getDocs(collection(db(A), 'conversations', cid, 'messages'));
  for (const m of msgs.docs) await assertSucceeds(deleteDoc(m.ref));
  await assertSucceeds(deleteDoc(doc(db(A), 'conversations', cid)));
  await assertSucceeds(deleteDoc(doc(db(A), 'profiles', A)));
  await assertFails(deleteDoc(doc(db(A), 'profiles', B)));
});

test('прочие коллекции закрыты', async () => {
  await assertFails(setDoc(doc(db(A), 'secrets', 'x'), { a: 1 }));
  await assertFails(getDoc(doc(db(A), 'secrets', 'x')));
});

// =============================================================== доски

const BID = 'board1';

function boardData(owner, extra = {}) {
  return {
    n: 'Статья в журнал', c: 1, ic: 'article', ow: owner, mb: [owner],
    rl: { [owner]: 'owner' },
    cols: [{ id: 'c1', n: 'Идеи', lim: 0, dn: false }, { id: 'c2', n: 'Готово', lim: 0, dn: true }],
    lbs: [], ar: false, tpl: 'paper', cr: serverTimestamp(), up: serverTimestamp(),
    ...extra,
  };
}

function cardData(by, extra = {}) {
  return {
    t: 'Обзор литературы', d: '', col: 'c1', o: 1024, due: null, p: 1,
    lb: [], as: [], ck: [], pp: [], gr: [], by,
    cr: serverTimestamp(), up: serverTimestamp(), dn: null, ...extra,
  };
}

/** Доска Алисы, где Боб — редактор, Кэрол — наблюдатель. */
async function sharedBoard() {
  await assertSucceeds(setDoc(doc(db(A), 'boards', BID), boardData(A)));
  await assertSucceeds(updateDoc(doc(db(A), 'boards', BID), {
    mb: [A, B, C], rl: { [A]: 'owner', [B]: 'editor', [C]: 'viewer' },
    up: serverTimestamp(),
  }));
}

test('доска: создать можно только себе и только владельцем', async () => {
  await assertSucceeds(setDoc(doc(db(A), 'boards', BID), boardData(A)));
  await assertFails(setDoc(doc(db(A), 'boards', 'b2'), boardData(B)));
  await assertFails(setDoc(doc(db(A), 'boards', 'b3'), boardData(A, { mb: [A, B], rl: { [A]: 'owner', [B]: 'editor' } })));
  await assertFails(setDoc(doc(db(A), 'boards', 'b4'), boardData(A, { n: '' })));
  await assertFails(setDoc(doc(db(A), 'boards', 'b5'), boardData(A, { admin: true })));
  await assertFails(setDoc(doc(db(A), 'boards', 'b6'), boardData(A, { cols: [] })));
});

test('доска: читают только участники', async () => {
  await sharedBoard();
  await assertSucceeds(getDoc(doc(db(B), 'boards', BID)));
  await assertSucceeds(getDoc(doc(db(C), 'boards', BID)));
  await assertFails(getDoc(doc(db(NOPROFILE), 'boards', BID)));
  await assertSucceeds(getDocs(query(collection(db(B), 'boards'), where('mb', 'array-contains', B))));
  await assertFails(getDocs(collection(db(B), 'boards')));
});

test('доска: редактор меняет колонки, но не участников; наблюдатель ничего', async () => {
  await sharedBoard();
  await assertSucceeds(updateDoc(doc(db(B), 'boards', BID), {
    cols: [{ id: 'c1', n: 'Идеи', lim: 3, dn: false }, { id: 'c2', n: 'Готово', lim: 0, dn: true }],
    up: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db(B), 'boards', BID), {
    rl: { [A]: 'owner', [B]: 'editor', [C]: 'editor' }, up: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db(C), 'boards', BID), { n: 'Взлом', up: serverTimestamp() }));
  await assertFails(updateDoc(doc(db(B), 'boards', BID), { ow: B, up: serverTimestamp() }));
});

test('доска: участник выходит сам, владелец выйти не может, но передаёт права', async () => {
  await sharedBoard();
  await assertSucceeds(updateDoc(doc(db(C), 'boards', BID), {
    mb: [A, B], rl: { [A]: 'owner', [B]: 'editor' }, up: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(db(C), 'boards', BID)));
  // Боб не может выгнать Алису.
  await assertFails(updateDoc(doc(db(B), 'boards', BID), {
    mb: [B], rl: { [B]: 'editor' }, up: serverTimestamp(),
  }));
  // Передача владения Бобу.
  await assertSucceeds(updateDoc(doc(db(A), 'boards', BID), {
    ow: B, rl: { [A]: 'editor', [B]: 'owner' }, up: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(db(A), 'boards', BID), {
    mb: [B], rl: { [B]: 'owner' }, up: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(db(A), 'boards', BID)));
  await assertSucceeds(deleteDoc(doc(db(B), 'boards', BID)));
});

test('карточки: редактор и владелец пишут, наблюдатель только читает', async () => {
  await sharedBoard();
  const ref = doc(collection(db(B), 'boards', BID, 'cards'));
  await assertSucceeds(setDoc(ref, cardData(B)));
  await assertSucceeds(getDocs(collection(db(C), 'boards', BID, 'cards')));
  await assertFails(setDoc(doc(collection(db(C), 'boards', BID, 'cards')), cardData(C)));
  await assertFails(updateDoc(doc(db(C), 'boards', BID, 'cards', ref.id), { col: 'c2', up: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(db(A), 'boards', BID, 'cards', ref.id), {
    col: 'c2', o: 2048, dn: serverTimestamp(), up: serverTimestamp(),
  }));
  await assertFails(getDocs(collection(db(NOPROFILE), 'boards', BID, 'cards')));
  await assertFails(deleteDoc(doc(db(C), 'boards', BID, 'cards', ref.id)));
  await assertSucceeds(deleteDoc(doc(db(B), 'boards', BID, 'cards', ref.id)));
});

test('карточки: проверка полей', async () => {
  await sharedBoard();
  const col = collection(db(B), 'boards', BID, 'cards');
  await assertFails(setDoc(doc(col), cardData(B, { t: '' })));
  await assertFails(setDoc(doc(col), cardData(B, { t: 'x'.repeat(201) })));
  await assertFails(setDoc(doc(col), cardData(B, { p: 7 })));
  await assertFails(setDoc(doc(col), cardData(A))); // от чужого имени
  await assertFails(setDoc(doc(col), cardData(B, { hack: 1 })));
  await assertFails(setDoc(doc(col), cardData(B, { up: Timestamp.fromMillis(0) })));
  await assertSucceeds(setDoc(doc(col), cardData(B, { due: Timestamp.now(), p: 3, as: [A, B] })));
});

test('комментарии и история: пишут редакторы, читают участники', async () => {
  await sharedBoard();
  const card = doc(collection(db(B), 'boards', BID, 'cards'));
  await setDoc(card, cardData(B));
  const cm = (who) => ({ by: who, t: 'Готово к проверке', at: serverTimestamp() });
  await assertSucceeds(setDoc(doc(collection(db(B), 'boards', BID, 'cards', card.id, 'comments')), cm(B)));
  await assertFails(setDoc(doc(collection(db(C), 'boards', BID, 'cards', card.id, 'comments')), cm(C)));
  await assertSucceeds(getDocs(collection(db(C), 'boards', BID, 'cards', card.id, 'comments')));
  const act = (who) => ({ by: who, k: 'move', card: card.id, ct: 'Обзор', from: 'Идеи', to: 'Готово', at: serverTimestamp() });
  await assertSucceeds(setDoc(doc(collection(db(B), 'boards', BID, 'activity')), act(B)));
  await assertFails(setDoc(doc(collection(db(C), 'boards', BID, 'activity')), act(C)));
  await assertFails(setDoc(doc(collection(db(B), 'boards', BID, 'activity')), act(A)));
  await assertSucceeds(getDocs(collection(db(C), 'boards', BID, 'activity')));
});

test('время фокуса: каждый прибавляет только своё, не больше 4 часов за раз', async () => {
  await sharedBoard();
  const card = doc(collection(db(B), 'boards', BID, 'cards'));
  await assertFails(setDoc(doc(collection(db(B), 'boards', BID, 'cards')), cardData(B, { ft: { [B]: 600 } })));
  await assertSucceeds(setDoc(card, cardData(B)));
  const ref = (u) => doc(db(u), 'boards', BID, 'cards', card.id);
  await assertSucceeds(updateDoc(ref(B), { [`ft.${B}`]: increment(1500), up: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref(A), { [`ft.${A}`]: increment(300), up: serverTimestamp() }));
  // Чужое время менять нельзя.
  await assertFails(updateDoc(ref(A), { [`ft.${B}`]: increment(60), up: serverTimestamp() }));
  // Уменьшать нельзя, больше 4 часов за раз нельзя, не число нельзя.
  await assertFails(updateDoc(ref(B), { [`ft.${B}`]: 10, up: serverTimestamp() }));
  await assertFails(updateDoc(ref(B), { [`ft.${B}`]: increment(14401), up: serverTimestamp() }));
  await assertFails(updateDoc(ref(B), { [`ft.${B}`]: 'много', up: serverTimestamp() }));
  // Наблюдатель не пишет.
  await assertFails(updateDoc(ref(C), { [`ft.${C}`]: increment(60), up: serverTimestamp() }));
  // Остальные правки карточки не задевают время.
  await assertSucceeds(updateDoc(ref(B), { col: 'c2', o: 2048, dn: serverTimestamp(), up: serverTimestamp() }));
  const snap = await getDoc(ref(C));
  if (snap.data().ft[B] !== 1500 || snap.data().ft[A] !== 300) throw new Error('ft');
});

test('доска со стартовыми карточками создаётся одним пакетом', async () => {
  const da = db(A);
  const b = writeBatch(da);
  b.set(doc(da, 'boards', 'tpl1'), boardData(A));
  b.set(doc(collection(da, 'boards', 'tpl1', 'cards')), cardData(A));
  b.set(doc(collection(da, 'boards', 'tpl1', 'cards')), cardData(A, { t: 'Вторая' }));
  await assertSucceeds(b.commit());
  // Посторонний не может добавить карточки в чужую доску.
  const dbB = db(B);
  const bad = writeBatch(dbB);
  bad.set(doc(collection(dbB, 'boards', 'tpl1', 'cards')), cardData(B));
  await assertFails(bad.commit());
});

test('удаление доски владельцем: комментарии, карточки, история, доска', async () => {
  await sharedBoard();
  const da = db(A);
  const card = doc(collection(da, 'boards', BID, 'cards'));
  await assertSucceeds(setDoc(card, cardData(A)));
  await assertSucceeds(setDoc(doc(collection(da, 'boards', BID, 'cards', card.id, 'comments')),
    { by: A, t: 'Комментарий', at: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(collection(da, 'boards', BID, 'activity')),
    { by: A, k: 'create', card: card.id, ct: 'x', from: '', to: '', at: serverTimestamp() }));
  // Как BoardService.deleteBoard: читаем и удаляем пакетами.
  const cm = await assertSucceeds(getDocs(collection(da, 'boards', BID, 'cards', card.id, 'comments')));
  let b = writeBatch(da);
  cm.docs.forEach((d) => b.delete(d.ref));
  await assertSucceeds(b.commit());
  const cards = await assertSucceeds(getDocs(collection(da, 'boards', BID, 'cards')));
  b = writeBatch(da);
  cards.docs.forEach((d) => b.delete(d.ref));
  await assertSucceeds(b.commit());
  const act = await assertSucceeds(getDocs(collection(da, 'boards', BID, 'activity')));
  b = writeBatch(da);
  act.docs.forEach((d) => b.delete(d.ref));
  await assertSucceeds(b.commit());
  await assertSucceeds(deleteDoc(doc(da, 'boards', BID)));
});
