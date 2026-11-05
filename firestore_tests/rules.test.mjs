// Тесты правил Firestore в эмуляторе: node --test (через firebase emulators:exec).
import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, collection, getDocs,
  query, where, serverTimestamp, arrayUnion, arrayRemove, Timestamp,
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
