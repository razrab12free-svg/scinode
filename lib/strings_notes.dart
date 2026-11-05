// Тексты заметок с формулами LaTeX. Порядок: русский, узбекский, английский.
const Map<String, List<String>> noteStrings = {
  'nt.tile': ['Заметки и формулы', 'Qaydlar va formulalar', 'Notes & formulas'],
  'nt.tile_sub': [
    'Записи к статьям и задачам с формулами LaTeX',
    'Maqola va vazifalarga LaTeX formulali qaydlar',
    'Notes on papers and tasks with LaTeX formulas',
  ],
  'nt.title': ['Заметки', 'Qaydlar', 'Notes'],
  'nt.note': ['Заметка', 'Qayd', 'Note'],
  'nt.new': ['Новая заметка', 'Yangi qayd', 'New note'],
  'nt.new_page': [
    'Новая заметка к стр. {p}',
    '{p}-sahifaga yangi qayd',
    'New note for page {p}',
  ],
  'nt.untitled': ['Без названия', 'Nomsiz', 'Untitled'],
  'nt.page': ['стр. {p}', '{p}-sahifa', 'p. {p}'],
  'nt.formulas': ['формул: {n}', 'formulalar: {n}', 'formulas: {n}'],
  'nt.search': [
    'Поиск по заметкам',
    'Qaydlardan qidirish',
    'Search notes',
  ],
  'nt.f.all': ['Все', 'Hammasi', 'All'],
  'nt.f.papers': ['К статьям', 'Maqolalarga', 'On papers'],
  'nt.f.tasks': ['К задачам', 'Vazifalarga', 'On tasks'],
  'nt.f.free': ['Свободные', 'Erkin', 'Standalone'],
  'nt.empty_title': [
    'Пока нет заметок',
    'Hozircha qaydlar yo‘q',
    'No notes yet',
  ],
  'nt.empty_text': [
    'Записывайте выводы, идеи и формулы прямо с телефона. Формулы набираются кнопками над клавиатурой и сразу видны готовыми.',
    'Xulosalar, g‘oyalar va formulalarni to‘g‘ridan-to‘g‘ri telefondan yozing. Formulalar klaviatura ustidagi tugmalar bilan teriladi va darhol tayyor ko‘rinadi.',
    'Write down findings, ideas and formulas right on your phone. Type formulas with the buttons above the keyboard and see them rendered at once.',
  ],
  'nt.not_ready': [
    'Войдите в аккаунт, чтобы вести заметки.',
    'Qaydlar yuritish uchun hisobingizga kiring.',
    'Sign in to keep notes.',
  ],
  'nt.err.load': [
    'Не удалось загрузить заметки. Проверьте интернет.',
    'Qaydlarni yuklab bo‘lmadi. Internetni tekshiring.',
    'Could not load notes. Check your internet connection.',
  ],
  'nt.title_hint': ['Заголовок', 'Sarlavha', 'Title'],
  'nt.body_hint': [
    'Текст заметки. Формула в строке: \$E=mc^2\$, отдельной строкой: \$\$…\$\$',
    'Qayd matni. Qatordagi formula: \$E=mc^2\$, alohida qator: \$\$…\$\$',
    'Note text. Inline formula: \$E=mc^2\$, on its own line: \$\$…\$\$',
  ],
  'nt.preview': ['Просмотр', 'Ko‘rish', 'Preview'],
  'nt.edit': ['Редактировать', 'Tahrirlash', 'Edit'],
  'nt.preview_empty': [
    'Заметка пока пустая',
    'Qayd hozircha bo‘sh',
    'The note is empty',
  ],
  'nt.hint_math': [
    'Нажмите кнопку с формулой ниже — она появится в тексте, а здесь будет видна готовой',
    'Quyidagi formula tugmasini bosing — u matnda paydo bo‘ladi, bu yerda esa tayyor ko‘rinadi',
    'Tap a formula button below: it goes into the text and is shown rendered here',
  ],
  'nt.unclosed': [
    'Формула не закрыта: поставьте \$ в конце',
    'Formula yopilmagan: oxiriga \$ qo‘ying',
    'The formula isn’t closed: add \$ at the end',
  ],
  'nt.formula_error': [
    'Ошибка в формуле: {e}',
    'Formulada xato: {e}',
    'Formula error: {e}',
  ],
  'nt.copy_text': [
    'Скопировать текст (Markdown + LaTeX)',
    'Matnni nusxalash (Markdown + LaTeX)',
    'Copy text (Markdown + LaTeX)',
  ],
  'nt.copy_formulas': [
    'Скопировать формулы LaTeX ({n})',
    'LaTeX formulalarini nusxalash ({n})',
    'Copy LaTeX formulas ({n})',
  ],
  'nt.copied': [
    'Текст скопирован',
    'Matn nusxalandi',
    'Text copied',
  ],
  'nt.copied_formulas': [
    'Формулы скопированы — вставьте в Overleaf или Word',
    'Formulalar nusxalandi — Overleaf yoki Word’ga joylang',
    'Formulas copied — paste them into Overleaf or Word',
  ],
  'nt.link_paper': [
    'Привязать к статье из библиотеки',
    'Kutubxonadagi maqolaga bog‘lash',
    'Link to a library paper',
  ],
  'nt.unlink_paper': [
    'Отвязать от статьи',
    'Maqoladan uzish',
    'Unlink from paper',
  ],
  'nt.delete': ['Удалить заметку', 'Qaydni o‘chirish', 'Delete note'],
  'nt.delete_q': [
    'Заметка будет удалена без возможности восстановления.',
    'Qayd qayta tiklab bo‘lmaydigan tarzda o‘chiriladi.',
    'The note will be deleted permanently.',
  ],
  'nt.deleted': [
    'Заметка удалена',
    'Qayd o‘chirildi',
    'Note deleted',
  ],
  'nt.for_paper': [
    'Заметки к статье',
    'Maqolaga qaydlar',
    'Notes on this paper',
  ],
  'nt.for_paper_act': ['Заметка к статье', 'Maqolaga qayd', 'Note on paper'],
  'nt.for_page': [
    'Заметка к этой странице',
    'Shu sahifaga qayd',
    'Note on this page',
  ],
  'nt.card_none': [
    'Личные заметки к задаче видите только вы',
    'Vazifaga shaxsiy qaydlarni faqat siz ko‘rasiz',
    'Only you can see your notes on this task',
  ],
  // Подсказки кнопок панели формул.
  'nt.k.inline': [
    'Формула в строке',
    'Qatordagi formula',
    'Inline formula',
  ],
  'nt.k.block': [
    'Формула отдельной строкой',
    'Alohida qatordagi formula',
    'Formula on its own line',
  ],
  'nt.k.frac': ['Дробь', 'Kasr', 'Fraction'],
  'nt.k.pow': ['Степень', 'Daraja', 'Power'],
  'nt.k.sub': ['Индекс', 'Indeks', 'Subscript'],
  'nt.k.sqrt': ['Корень', 'Ildiz', 'Square root'],
  'nt.k.sum': ['Сумма', 'Yig‘indi', 'Sum'],
  'nt.k.int': ['Интеграл', 'Integral', 'Integral'],
  'nt.k.lim': ['Предел', 'Limit', 'Limit'],
  'nt.k.vec': ['Вектор', 'Vektor', 'Vector'],
  'nt.k.bar': ['Среднее', 'O‘rtacha', 'Mean'],
  'nt.k.paren': ['Скобки', 'Qavslar', 'Brackets'],
  'nt.k.matrix': ['Матрица', 'Matritsa', 'Matrix'],
  'nt.k.bold': ['Жирный', 'Qalin', 'Bold'],
  'nt.k.head': ['Заголовок', 'Sarlavha', 'Heading'],
  'nt.k.list': ['Список', 'Ro‘yxat', 'List'],
  // Выгрузка и шаблоны (8.2).
  'nt.export_pdf': [
    'Экспорт в PDF',
    'PDF’ga eksport',
    'Export to PDF',
  ],
  'nt.export_tex': [
    'Экспорт в LaTeX (.tex) для Overleaf',
    'Overleaf uchun LaTeX’ga (.tex) eksport',
    'Export to LaTeX (.tex) for Overleaf',
  ],
  'nt.export_md': [
    'Экспорт в Markdown (.md)',
    'Markdown’ga (.md) eksport',
    'Export to Markdown (.md)',
  ],
  'nt.share_err': [
    'Не удалось поделиться файлом. Попробуйте ещё раз.',
    'Fayl bilan ulashib bo‘lmadi. Qayta urinib ko‘ring.',
    'Could not share the file. Please try again.',
  ],
  'nt.pdf_kind': ['ЗАМЕТКА', 'QAYD', 'NOTE'],
  'nt.tex_made': [
    'Создано в Scinode. Компилятор в Overleaf: pdfLaTeX.',
    'Scinode’da yaratilgan. Overleaf’dagi kompilyator: pdfLaTeX.',
    'Made with Scinode. Overleaf compiler: pdfLaTeX.',
  ],
  'nt.templates': [
    'Шаблоны формул',
    'Formula shablonlari',
    'Formula templates'
  ],
  'nt.mine': ['Мои формулы', 'Mening formulalarim', 'My formulas'],
  'ft.cat.math': ['Математика', 'Matematika', 'Mathematics'],
  'ft.cat.physics': ['Физика', 'Fizika', 'Physics'],
  'ft.cat.stats': ['Статистика', 'Statistika', 'Statistics'],
  'ft.cat.chem': [
    'Химия и биология',
    'Kimyo va biologiya',
    'Chemistry & biology'
  ],
  'ft.quad': [
    'Корни квадратного уравнения',
    'Kvadrat tenglama ildizlari',
    'Quadratic formula'
  ],
  'ft.pyth': ['Теорема Пифагора', 'Pifagor teoremasi', 'Pythagorean theorem'],
  'ft.deriv': [
    'Определение производной',
    'Hosila ta’rifi',
    'Definition of derivative'
  ],
  'ft.taylor': ['Ряд Тейлора', 'Teylor qatori', 'Taylor series'],
  'ft.euler': ['Тождество Эйлера', 'Eyler ayniyati', 'Euler’s identity'],
  'ft.parts': [
    'Интегрирование по частям',
    'Bo‘laklab integrallash',
    'Integration by parts'
  ],
  'ft.matrix': ['Матрица 2×2', '2×2 matritsa', '2×2 matrix'],
  'ft.det': ['Определитель 2×2', '2×2 determinant', '2×2 determinant'],
  'ft.newton': [
    'Второй закон Ньютона',
    'Nyutonning ikkinchi qonuni',
    'Newton’s second law'
  ],
  'ft.energy': [
    'Энергия покоя',
    'Tinchlik energiyasi',
    'Mass–energy equivalence'
  ],
  'ft.kinetic': ['Кинетическая энергия', 'Kinetik energiya', 'Kinetic energy'],
  'ft.gravity': [
    'Закон всемирного тяготения',
    'Butun olam tortishish qonuni',
    'Law of gravitation'
  ],
  'ft.ohm': ['Закон Ома', 'Om qonuni', 'Ohm’s law'],
  'ft.schrodinger': [
    'Уравнение Шрёдингера',
    'Shryodinger tenglamasi',
    'Schrödinger equation'
  ],
  'ft.gas': [
    'Уравнение идеального газа',
    'Ideal gaz tenglamasi',
    'Ideal gas law'
  ],
  'ft.wave': ['Скорость волны', 'To‘lqin tezligi', 'Wave speed'],
  'ft.mean': ['Среднее арифметическое', 'O‘rta arifmetik', 'Arithmetic mean'],
  'ft.sd': [
    'Стандартное отклонение выборки',
    'Tanlanma standart chetlanishi',
    'Sample standard deviation'
  ],
  'ft.normal': [
    'Нормальное распределение',
    'Normal taqsimot',
    'Normal distribution'
  ],
  'ft.bayes': ['Формула Байеса', 'Bayes formulasi', 'Bayes’ theorem'],
  'ft.ttest': ['t-критерий Стьюдента', 'Styudent t-mezoni', 'Student’s t-test'],
  'ft.pearson': [
    'Коэффициент корреляции Пирсона',
    'Pirson korrelyatsiya koeffitsiyenti',
    'Pearson correlation'
  ],
  'ft.ci': [
    'Доверительный интервал',
    'Ishonch oralig‘i',
    'Confidence interval'
  ],
  'ft.regression': [
    'Линейная регрессия',
    'Chiziqli regressiya',
    'Linear regression'
  ],
  'ft.arrhenius': [
    'Уравнение Аррениуса',
    'Arrenius tenglamasi',
    'Arrhenius equation'
  ],
  'ft.ph': ['Водородный показатель', 'Vodorod ko‘rsatkichi', 'pH'],
  'ft.henderson': [
    'Уравнение Гендерсона — Хассельбаха',
    'Genderson — Xasselbax tenglamasi',
    'Henderson–Hasselbalch equation'
  ],
  'ft.michaelis': [
    'Уравнение Михаэлиса — Ментен',
    'Mixaelis — Menten tenglamasi',
    'Michaelis–Menten equation'
  ],
  'ft.gibbs': ['Энергия Гиббса', 'Gibbs energiyasi', 'Gibbs free energy'],
  'ft.beer': [
    'Закон Бугера — Ламберта — Бера',
    'Buger — Lambert — Ber qonuni',
    'Beer–Lambert law'
  ],
  'ft.growth': [
    'Экспоненциальный рост',
    'Eksponensial o‘sish',
    'Exponential growth'
  ],
  'ft.photo': ['Фотосинтез', 'Fotosintez', 'Photosynthesis'],
};
