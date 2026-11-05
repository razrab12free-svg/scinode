// Тексты для PDF. Порядок: русский, узбекский, английский.
const Map<String, List<String>> pdfStrings = {
  'pdf.download': [
    'Скачать в библиотеку',
    'Kutubxonaga yuklab olish',
    'Download to library',
  ],
  'pdf.downloading': [
    'Скачивание… {p}%',
    'Yuklanmoqda… {p}%',
    'Downloading… {p}%',
  ],
  'pdf.downloading_plain': [
    'Скачивание…',
    'Yuklanmoqda…',
    'Downloading…',
  ],
  'pdf.cancel': ['Отмена', 'Bekor qilish', 'Cancel'],
  'pdf.read': ['Читать', 'O‘qish', 'Read'],
  'pdf.remove': [
    'Удалить с телефона',
    'Telefondan o‘chirish',
    'Remove from phone',
  ],
  'pdf.saved_info': [
    'PDF сохранён в приложении ({size})',
    'PDF ilovada saqlangan ({size})',
    'PDF saved in the app ({size})',
  ],
  'pdf.err.notpdf': [
    'Источник не отдаёт PDF напрямую. Откройте статью в браузере',
    'Manba PDF ni to‘g‘ridan-to‘g‘ri bermaydi. Maqolani brauzerda oching',
    'The source does not provide a direct PDF. Open the article in your browser',
  ],
  'pdf.err.toolarge': [
    'Файл слишком большой (больше 80 МБ)',
    'Fayl juda katta (80 MB dan ortiq)',
    'The file is too large (over 80 MB)',
  ],
  'pdf.err.network': [
    'Не удалось скачать. Проверьте интернет и повторите',
    'Yuklab bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring',
    'Download failed. Check your internet and try again',
  ],
  'pdf.err.http': [
    'Сервер не разрешил скачивание. Откройте статью в браузере',
    'Server yuklab olishga ruxsat bermadi. Maqolani brauzerda oching',
    'The server did not allow the download. Open the article in your browser',
  ],
  'pdf.err.nosource': [
    'Бесплатный PDF не найден',
    'Bepul PDF topilmadi',
    'No free PDF found',
  ],
  'pdf.night': ['Ночной режим', 'Tungi rejim', 'Night mode'],
  'pdf.page': ['{p} / {n}', '{p} / {n}', '{p} / {n}'],
  'pdf.badge': ['PDF', 'PDF', 'PDF'],
  'pdf.legal': [
    'Скачиваются только легальные открытые версии. Файл хранится только на вашем телефоне.',
    'Faqat qonuniy ochiq nusxalar yuklab olinadi. Fayl faqat telefoningizda saqlanadi.',
    'Only legal open versions are downloaded. The file stays on your phone only.',
  ],
  'storage.title': [
    'Скачанные PDF',
    'Yuklab olingan PDF',
    'Downloaded PDFs',
  ],
  'storage.info': [
    '{n} файлов · {size}',
    '{n} ta fayl · {size}',
    '{n} files · {size}',
  ],
  'storage.clear': ['Очистить', 'Tozalash', 'Clear'],
  'storage.clear_q': [
    'Удалить все скачанные PDF с телефона?',
    'Yuklab olingan barcha PDF telefondan o‘chirilsinmi?',
    'Delete all downloaded PDFs from this phone?',
  ],
};
