// Тексты раздела Zotero. Порядок: русский, узбекский, английский.
const Map<String, List<String>> zoteroStrings = {
  'zt.title': ['Zotero', 'Zotero', 'Zotero'],
  'zt.button': ['Zotero', 'Zotero', 'Zotero'],
  'zt.hero_title': [
    'Ваша библиотека Zotero в Scinode',
    'Zotero kutubxonangiz Scinode’da',
    'Your Zotero library in Scinode',
  ],
  'zt.hero_text': [
    'Переносите статьи из Zotero в библиотеку Scinode — с поиском PDF и читалкой — и отправляйте найденные здесь статьи обратно в Zotero. Это бесплатно.',
    'Maqolalarni Zotero’dan Scinode kutubxonasiga o‘tkazing — PDF qidiruvi va o‘quvchi bilan — va bu yerda topilgan maqolalarni Zotero’ga yuboring. Bu bepul.',
    'Bring papers from Zotero into your Scinode library — with PDF search and the reader — and send papers you find here back to Zotero. It’s free.',
  ],
  'zt.how': ['Как подключить', 'Qanday ulash mumkin', 'How to connect'],
  'zt.step1': [
    'Войдите на сайт zotero.org (бесплатный аккаунт Zotero).',
    'zotero.org saytiga kiring (bepul Zotero hisobi).',
    'Sign in at zotero.org (a free Zotero account).',
  ],
  'zt.step2': [
    'Откройте страницу ключей:',
    'Kalitlar sahifasini oching:',
    'Open the keys page:',
  ],
  'zt.step3': [
    'Нажмите «Create new private key». Включите «Allow library access», а для отправки статей в Zotero — ещё «Allow write access». Нажмите «Save Key».',
    '«Create new private key» tugmasini bosing. «Allow library access»ni, maqolalarni Zotero’ga yuborish uchun esa «Allow write access»ni ham yoqing. «Save Key»ni bosing.',
    'Tap “Create new private key”. Turn on “Allow library access”, and “Allow write access” to send papers to Zotero. Tap “Save Key”.',
  ],
  'zt.step4': [
    'Скопируйте ключ (строка из букв и цифр) и вставьте ниже.',
    'Kalitni (harf va raqamlar qatori) nusxalab, quyiga joylang.',
    'Copy the key (a string of letters and digits) and paste it below.',
  ],
  'zt.key': ['Ключ Zotero', 'Zotero kaliti', 'Zotero key'],
  'zt.key_hint': [
    '24 знака: латинские буквы и цифры',
    '24 ta belgi: lotin harflari va raqamlar',
    '24 characters: letters and digits',
  ],
  'zt.show': ['Показать ключ', 'Kalitni ko‘rsatish', 'Show key'],
  'zt.hide': ['Скрыть ключ', 'Kalitni yashirish', 'Hide key'],
  'zt.key_safe': [
    'Ключ хранится только на этом телефоне в защищённом хранилище. Номер пользователя Zotero приложение узнает само.',
    'Kalit faqat shu telefonda himoyalangan xotirada saqlanadi. Zotero foydalanuvchi raqamini ilova o‘zi aniqlaydi.',
    'The key is stored only on this phone, in secure storage. The app finds your Zotero user ID by itself.',
  ],
  'zt.connect': ['Подключить Zotero', 'Zotero’ni ulash', 'Connect Zotero'],
  'zt.free': [
    'Перенос статей не тратит место в хранилище Zotero: передаются только сведения о статьях, без файлов.',
    'Maqolalarni ko‘chirish Zotero xotirasini egallamaydi: fayllarsiz faqat maqola ma’lumotlari uzatiladi.',
    'Transfers don’t use your Zotero storage: only paper details are sent, no files.',
  ],
  'zt.connected_ok': [
    'Zotero подключён',
    'Zotero ulandi',
    'Zotero connected',
  ],
  'zt.connected': ['Zotero подключён', 'Zotero ulangan', 'Zotero connected'],
  'zt.rw': [
    'Чтение и запись',
    'O‘qish va yozish',
    'Read and write',
  ],
  'zt.ro': [
    'Только чтение: отправка в Zotero выключена',
    'Faqat o‘qish: Zotero’ga yuborish o‘chirilgan',
    'Read only: sending to Zotero is off',
  ],
  'zt.import': ['Импорт из Zotero', 'Zotero’dan import', 'Import from Zotero'],
  'zt.import_sub': [
    'Перенести статьи в библиотеку Scinode',
    'Maqolalarni Scinode kutubxonasiga o‘tkazish',
    'Add papers to your Scinode library',
  ],
  'zt.export': ['Экспорт в Zotero', 'Zotero’ga eksport', 'Export to Zotero'],
  'zt.export_sub': [
    'Отправить статьи из библиотеки Scinode',
    'Scinode kutubxonasidan maqolalarni yuborish',
    'Send papers from your Scinode library',
  ],
  'zt.export_no_write': [
    'У ключа нет права записи. Создайте ключ с «Allow write access».',
    'Kalitda yozish huquqi yo‘q. «Allow write access» bilan kalit yarating.',
    'This key can’t write. Create a key with “Allow write access”.',
  ],
  'zt.disconnect': ['Отключить Zotero', 'Zotero’ni uzish', 'Disconnect Zotero'],
  'zt.disconnect_q': [
    'Ключ будет удалён с этого телефона. Статьи в библиотеке Scinode и в Zotero останутся.',
    'Kalit bu telefondan o‘chiriladi. Scinode va Zotero’dagi maqolalar qoladi.',
    'The key will be removed from this phone. Papers in Scinode and Zotero stay.',
  ],
  'zt.disconnect_do': ['Отключить', 'Uzish', 'Disconnect'],
  'zt.choose_collection': [
    'Коллекция Zotero',
    'Zotero to‘plami',
    'Zotero collection',
  ],
  'zt.all': ['Вся библиотека', 'Butun kutubxona', 'Whole library'],
  'zt.root': [
    'Без коллекции (в библиотеку)',
    'To‘plamsiz (kutubxonaga)',
    'No collection (library)',
  ],
  'zt.new_collection': [
    'Новая коллекция',
    'Yangi to‘plam',
    'New collection',
  ],
  'zt.to': ['Куда', 'Qayerga', 'To'],
  'zt.pick_all': [
    'Выбрать все ({n})',
    'Hammasini tanlash ({n})',
    'Select all ({n})'
  ],
  'zt.pick_none': ['Снять выбор', 'Tanlovni bekor qilish', 'Clear selection'],
  'zt.loading': [
    'Загружаем статьи из Zotero…',
    'Zotero’dan maqolalar yuklanmoqda…',
    'Loading papers from Zotero…',
  ],
  'zt.checking': [
    'Проверяем, что уже есть в Zotero…',
    'Zotero’da nimalar borligi tekshirilmoqda…',
    'Checking what’s already in Zotero…',
  ],
  'zt.empty': [
    'Здесь пока нет записей',
    'Bu yerda hozircha yozuvlar yo‘q',
    'No items here yet',
  ],
  'zt.library_empty': [
    'Библиотека Scinode пуста. Сохраните статьи в поиске, и их можно будет отправить в Zotero.',
    'Scinode kutubxonasi bo‘sh. Qidiruvda maqolalarni saqlang, keyin ularni Zotero’ga yuborish mumkin.',
    'Your Scinode library is empty. Save papers from search to send them to Zotero.',
  ],
  'zt.summary': [
    'Записей: {n}, с DOI: {d}. Без DOI перенести нельзя: для них не найти PDF.',
    'Yozuvlar: {n}, DOI bilan: {d}. DOI’siz ko‘chirib bo‘lmaydi: ular uchun PDF topilmaydi.',
    'Items: {n}, with DOI: {d}. Items without a DOI can’t be imported: no PDF can be found for them.',
  ],
  'zt.in_library': [
    'Уже в библиотеке',
    'Kutubxonada bor',
    'Already in library'
  ],
  'zt.in_zotero': ['Уже в Zotero', 'Zotero’da bor', 'Already in Zotero'],
  'zt.no_doi': ['Нет DOI', 'DOI yo‘q', 'No DOI'],
  'zt.import_do': [
    'Перенести в библиотеку ({n})',
    'Kutubxonaga o‘tkazish ({n})',
    'Add to library ({n})',
  ],
  'zt.imported': [
    'Добавлено в библиотеку: {n}',
    'Kutubxonaga qo‘shildi: {n}',
    'Added to library: {n}',
  ],
  'zt.export_do': [
    'Отправить в Zotero ({n})',
    'Zotero’ga yuborish ({n})',
    'Send to Zotero ({n})',
  ],
  'zt.export_done': ['Готово', 'Tayyor', 'Done'],
  'zt.export_created': [
    'Добавлено в Zotero: {n}',
    'Zotero’ga qo‘shildi: {n}',
    'Added to Zotero: {n}',
  ],
  'zt.export_skipped': [
    'Уже были в Zotero (пропущены): {n}',
    'Zotero’da bor edi (o‘tkazib yuborildi): {n}',
    'Already in Zotero (skipped): {n}',
  ],
  'zt.export_failed': [
    'Не удалось отправить: {n}',
    'Yuborib bo‘lmadi: {n}',
    'Could not send: {n}',
  ],
  'zt.retry': ['Повторить', 'Qayta urinish', 'Try again'],
  'zt.err.key': [
    'Ключ не подошёл. Проверьте, что он скопирован целиком и не удалён на zotero.org.',
    'Kalit mos kelmadi. U to‘liq nusxalanganini va zotero.org’da o‘chirilmaganini tekshiring.',
    'The key didn’t work. Check it was copied in full and wasn’t deleted on zotero.org.',
  ],
  'zt.err.access': [
    'У ключа нет доступа к библиотеке. Создайте ключ с «Allow library access».',
    'Kalitda kutubxonaga kirish yo‘q. «Allow library access» bilan kalit yarating.',
    'This key has no library access. Create a key with “Allow library access”.',
  ],
  'zt.err.write': [
    'У ключа нет права записи. Создайте ключ с «Allow write access».',
    'Kalitda yozish huquqi yo‘q. «Allow write access» bilan kalit yarating.',
    'This key can’t write. Create a key with “Allow write access”.',
  ],
  'zt.err.network': [
    'Нет связи с Zotero. Проверьте интернет и попробуйте ещё раз.',
    'Zotero bilan aloqa yo‘q. Internetni tekshirib, qayta urinib ko‘ring.',
    'Can’t reach Zotero. Check your internet connection and try again.',
  ],
  'zt.err.busy': [
    'Zotero просит подождать. Попробуйте через минуту.',
    'Zotero kutishni so‘rayapti. Bir daqiqadan so‘ng urinib ko‘ring.',
    'Zotero asks to wait. Try again in a minute.',
  ],
  'zt.err.server': [
    'Zotero ответил ошибкой. Попробуйте позже.',
    'Zotero xato bilan javob berdi. Keyinroq urinib ko‘ring.',
    'Zotero returned an error. Please try later.',
  ],
  'zt.lib_import': [
    'Импорт из Zotero',
    'Zotero’dan import',
    'Import from Zotero',
  ],
};
