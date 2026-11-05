// Тексты чата и удаления данных. Порядок: русский, узбекский, английский.
const Map<String, List<String>> chatStrings = {
  'chat.title': ['Сообщения', 'Xabarlar', 'Messages'],
  'chat.write': ['Написать', 'Yozish', 'Message'],
  'chat.requests': [
    'Запросы на переписку',
    'Yozishma so‘rovlari',
    'Message requests'
  ],
  'chat.dialogs': ['Переписки', 'Yozishmalar', 'Conversations'],
  'chat.empty_title': [
    'Пока нет сообщений',
    'Hozircha xabarlar yo‘q',
    'No messages yet'
  ],
  'chat.empty_text': [
    'Найдите коллегу в разделе «В Scinode» и нажмите «Написать» в его карточке.',
    '«Scinode’da» bo‘limida hamkasbni toping va uning kartasida «Yozish» tugmasini bosing.',
    'Find a colleague under “On Scinode” and tap “Message” on their card.',
  ],
  'chat.deleted_user': [
    'Удалённый пользователь',
    'O‘chirilgan foydalanuvchi',
    'Deleted user',
  ],
  'chat.yesterday': ['Вчера', 'Kecha', 'Yesterday'],
  'chat.you': ['Вы: ', 'Siz: ', 'You: '],
  'chat.hint': ['Сообщение', 'Xabar', 'Message'],
  'chat.send': ['Отправить', 'Yuborish', 'Send'],
  'chat.sending': ['Отправляется…', 'Yuborilmoqda…', 'Sending…'],
  'chat.sent': ['Отправлено', 'Yuborildi', 'Sent'],
  'chat.read': ['Прочитано', 'O‘qildi', 'Read'],
  'chat.new_note': [
    'Первое сообщение станет запросом на переписку. Пока собеседник не ответит, можно отправить только одно сообщение — представьтесь и напишите, о чём хотите поговорить.',
    'Birinchi xabar yozishma so‘roviga aylanadi. Suhbatdosh javob bermaguncha faqat bitta xabar yuborish mumkin — o‘zingizni tanishtiring va nima haqida gaplashmoqchi ekaningizni yozing.',
    'Your first message becomes a message request. Until they reply you can send only one message — introduce yourself and say what you’d like to discuss.',
  ],
  'chat.wait': [
    'Запрос отправлен. Писать дальше можно будет, когда собеседник примет его.',
    'So‘rov yuborildi. Suhbatdosh qabul qilgach, yozishni davom ettirish mumkin bo‘ladi.',
    'Request sent. You can keep writing once they accept it.',
  ],
  'chat.incoming': [
    '{name} хочет начать с вами переписку.',
    '{name} siz bilan yozishma boshlamoqchi.',
    '{name} wants to start a conversation with you.',
  ],
  'chat.accept': ['Принять', 'Qabul qilish', 'Accept'],
  'chat.decline': ['Отклонить', 'Rad etish', 'Decline'],
  'chat.declined': [
    'Запрос на переписку отклонён.',
    'Yozishma so‘rovi rad etildi.',
    'The message request was declined.',
  ],
  'chat.blocked_me': [
    'Вы заблокировали этого пользователя.',
    'Siz bu foydalanuvchini blokladingiz.',
    'You blocked this user.',
  ],
  'chat.blocked_other': [
    'Переписка недоступна.',
    'Yozishma mavjud emas.',
    'This conversation is unavailable.',
  ],
  'chat.block': ['Заблокировать', 'Bloklash', 'Block'],
  'chat.unblock': ['Разблокировать', 'Blokdan chiqarish', 'Unblock'],
  'chat.block_q': [
    'Заблокировать пользователя? Вы оба больше не сможете писать в этой переписке, пока вы не снимете блокировку.',
    'Foydalanuvchi bloklansinmi? Blokni olib tashlamaguningizcha, ikkalangiz ham bu yozishmada yoza olmaysiz.',
    'Block this user? Neither of you will be able to write here until you unblock.',
  ],
  'chat.report': ['Пожаловаться', 'Shikoyat qilish', 'Report'],
  'chat.report_title': [
    'Жалоба на сообщение',
    'Xabar ustidan shikoyat',
    'Report message',
  ],
  'chat.report_hint': [
    'Что не так? (необязательно)',
    'Nima noto‘g‘ri? (ixtiyoriy)',
    'What is wrong? (optional)',
  ],
  'chat.report_sent': [
    'Жалоба отправлена. Спасибо!',
    'Shikoyat yuborildi. Rahmat!',
    'Report sent. Thank you!',
  ],
  'chat.copy': ['Копировать', 'Nusxalash', 'Copy'],
  'chat.copied': ['Текст скопирован', 'Matn nusxalandi', 'Text copied'],
  'chat.need_profile': [
    'Чтобы писать коллегам, опубликуйте свой профиль: Профиль → «Мой профиль учёного» → «Показывать мой профиль другим учёным».',
    'Hamkasblarga yozish uchun profilingizni e’lon qiling: Profil → «Mening olim profilim» → «Profilimni boshqa olimlarga ko‘rsatish».',
    'To message colleagues, publish your profile: Profile → “My scientist profile” → “Show my profile to other scientists”.',
  ],
  'chat.not_ready': [
    'Чат недоступен: войдите в аккаунт.',
    'Chat mavjud emas: hisobingizga kiring.',
    'Chat is unavailable: please sign in.',
  ],
  'chat.err.rules': [
    'Нет доступа. Проверьте, что ваш профиль опубликован, и что правила Firestore обновлены.',
    'Ruxsat yo‘q. Profilingiz e’lon qilinganini va Firestore qoidalari yangilanganini tekshiring.',
    'Access denied. Make sure your profile is published and Firestore rules are updated.',
  ],
  'chat.err.network': [
    'Нет связи. Сообщение отправится, когда появится интернет.',
    'Aloqa yo‘q. Internet paydo bo‘lganda xabar yuboriladi.',
    'No connection. The message will be sent when you are back online.',
  ],
  'chat.err.empty': [
    'Напишите текст сообщения',
    'Xabar matnini yozing',
    'Type a message'
  ],
  'chat.err.long': [
    'Сообщение длиннее 2000 символов',
    'Xabar 2000 belgidan uzun',
    'The message is longer than 2000 characters',
  ],
  'chat.err.other': [
    'Что-то пошло не так. Повторите попытку.',
    'Nimadir xato ketdi. Qayta urinib ko‘ring.',
    'Something went wrong. Please try again.',
  ],
  'chat.err.load': [
    'Не удалось загрузить сообщения.',
    'Xabarlarni yuklab bo‘lmadi.',
    'Could not load messages.',
  ],
  // Удаление данных.
  'del.button': [
    'Удалить мои данные',
    'Ma’lumotlarimni o‘chirish',
    'Delete my data'
  ],
  'del.title': [
    'Удалить мои данные?',
    'Ma’lumotlaringiz o‘chirilsinmi?',
    'Delete your data?'
  ],
  'del.text': [
    'Будут удалены: опубликованный профиль, все ваши переписки и сообщения (у собеседников тоже), личные доски, библиотека, скачанные PDF и прогресс чтения на этом телефоне. Из общих досок вы выйдете; для досок, где вы владелец, приложение спросит, кому передать права. Отменить это нельзя. После удаления вы выйдете из аккаунта.',
    'O‘chiriladi: e’lon qilingan profil, barcha yozishma va xabarlaringiz (suhbatdoshlarda ham), shaxsiy doskalar, kutubxona, yuklangan PDF va ushbu telefondagi o‘qish jarayoni. Umumiy doskalardan chiqasiz; egasi bo‘lgan doskalar uchun ilova huquqlarni kimga o‘tkazishni so‘raydi. Buni bekor qilib bo‘lmaydi. O‘chirgandan so‘ng hisobdan chiqasiz.',
    'This deletes your published profile, all your conversations and messages (for the other person too), your personal boards, library, downloaded PDFs and reading progress on this phone. You will leave shared boards; for boards you own, the app will ask who should take over. This cannot be undone. You will be signed out afterwards.',
  ],
  'del.confirm': ['Удалить навсегда', 'Butunlay o‘chirish', 'Delete forever'],
  'del.progress': [
    'Удаляем данные…',
    'Ma’lumotlar o‘chirilmoqda…',
    'Deleting your data…'
  ],
  'del.done': [
    'Ваши данные удалены',
    'Ma’lumotlaringiz o‘chirildi',
    'Your data has been deleted'
  ],
  'del.failed': [
    'Не всё удалось удалить: {err}. Проверьте интернет и повторите.',
    'Hammasini o‘chirib bo‘lmadi: {err}. Internetni tekshirib, qayta urinib ko‘ring.',
    'Not everything was deleted: {err}. Check your connection and try again.',
  ],
};
