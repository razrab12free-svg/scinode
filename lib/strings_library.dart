// Тексты библиотеки и читалки. Порядок: русский, узбекский, английский.
const Map<String, List<String>> libraryStrings = {
  'lib.search': [
    'Название, автор или журнал',
    'Sarlavha, muallif yoki jurnal',
    'Title, author or journal',
  ],
  'lib.f.all': ['Все', 'Hammasi', 'All'],
  'lib.f.pdf': ['Скачанные PDF', 'Yuklangan PDF', 'Downloaded'],
  'lib.f.nopdf': ['Без PDF', 'PDF siz', 'No PDF'],
  'lib.sort': ['Сортировка', 'Saralash', 'Sort'],
  'lib.sort.recent': [
    'Недавно добавленные',
    'Yaqinda qo‘shilganlar',
    'Recently added',
  ],
  'lib.sort.year': ['Сначала новые по году', 'Yil bo‘yicha', 'By year'],
  'lib.sort.cited': [
    'Больше цитирований',
    'Ko‘p iqtibos olganlar',
    'Most cited',
  ],
  'lib.nothing': [
    'Ничего не найдено',
    'Hech narsa topilmadi',
    'Nothing found',
  ],
  'lib.reset': ['Сбросить фильтры', 'Filtrlarni tozalash', 'Reset filters'],
  'lib.progress': ['стр. {p} из {n}', '{p}/{n}-bet', 'p. {p} of {n}'],
  'lib.progress_page': ['стр. {p}', '{p}-bet', 'p. {p}'],
  'lib.more': ['Действия', 'Amallar', 'Actions'],
  'lib.act.read': ['Читать PDF', 'PDF o‘qish', 'Read PDF'],
  'lib.act.details': [
    'Подробнее о статье',
    'Maqola haqida batafsil',
    'Article details',
  ],
  'lib.act.download': ['Скачать PDF', 'PDF yuklab olish', 'Download PDF'],
  'lib.act.remove_pdf': [
    'Удалить PDF с устройства',
    'PDF ni qurilmadan o‘chirish',
    'Delete PDF from device',
  ],
  'lib.act.remove': [
    'Удалить из библиотеки',
    'Kutubxonadan o‘chirish',
    'Remove from library',
  ],
  'lib.act.remove_q': [
    'Удалить статью из библиотеки? Скачанный PDF и прогресс чтения тоже будут удалены.',
    'Maqola kutubxonadan o‘chirilsinmi? Yuklangan PDF va o‘qish jarayoni ham o‘chiriladi.',
    'Remove this article from the library? Its downloaded PDF and reading progress will be deleted too.',
  ],
  'lib.act.delete': ['Удалить', 'O‘chirish', 'Delete'],
  'lib.removed': [
    'Статья удалена из библиотеки',
    'Maqola kutubxonadan o‘chirildi',
    'Removed from library',
  ],
  'lib.pdf_removed': [
    'PDF удалён с устройства, статья осталась в библиотеке',
    'PDF qurilmadan o‘chirildi, maqola kutubxonada qoldi',
    'PDF deleted from device; the article stays in your library',
  ],
  'lib.downloaded': [
    'PDF скачан в библиотеку',
    'PDF kutubxonaga yuklandi',
    'PDF downloaded to your library',
  ],
  'lib.open_in_lib': [
    'Открыть в библиотеке',
    'Kutubxonada ochish',
    'Open in library',
  ],
  'pdf.goto': ['Перейти к странице', 'Sahifaga o‘tish', 'Go to page'],
  'pdf.goto_hint': [
    'Номер страницы (1–{n})',
    'Sahifa raqami (1–{n})',
    'Page number (1–{n})',
  ],
  'pdf.goto_bad': [
    'Введите число от 1 до {n}',
    '1 dan {n} gacha son kiriting',
    'Enter a number from 1 to {n}',
  ],
  'pdf.go': ['Перейти', 'O‘tish', 'Go'],
  'pdf.fullscreen': [
    'Полный экран (нажмите на страницу, чтобы вернуть панель)',
    'To‘liq ekran (panelni qaytarish uchun sahifaga bosing)',
    'Full screen (tap the page to bring the bar back)',
  ],
  'pdf.err.open': [
    'Не удалось открыть PDF: файл повреждён или удалён. Скачайте его заново.',
    'PDF ni ochib bo‘lmadi: fayl buzilgan yoki o‘chirilgan. Uni qayta yuklab oling.',
    'Could not open the PDF: the file is damaged or missing. Please download it again.',
  ],
  'pdf.back': ['Назад', 'Orqaga', 'Back'],
};
