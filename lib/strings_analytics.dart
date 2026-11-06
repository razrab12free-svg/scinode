// Тексты «Scinode Аналитика». Порядок: русский, узбекский, английский.
const Map<String, List<String>> analyticsStrings = {
  'an.tile': ['Аналитика', 'Analitika', 'Analytics'],
  'an.tile_sub': [
    'Наука вузов и НИИ Узбекистана: публикации, цитирование, партнёры',
    'O‘zbekiston OTM va ilmiy institutlari: nashrlar, iqtiboslar, hamkorlar',
    'Research at Uzbekistan’s universities and institutes: papers, citations, partners',
  ],
  'an.title': ['Scinode Аналитика', 'Scinode Analitika', 'Scinode Analytics'],
  'an.intro': [
    'Показатели вузов и научных организаций Узбекистана по открытым данным OpenAlex. Обновляется раз в месяц.',
    'O‘zbekiston OTM va ilmiy tashkilotlari ko‘rsatkichlari — OpenAlex ochiq ma’lumotlari asosida. Oyiga bir marta yangilanadi.',
    'Indicators for Uzbekistan’s universities and research organizations from open OpenAlex data. Updated monthly.',
  ],
  'an.updated': [
    'Данные на {date} · период {from}–{to}',
    'Ma’lumotlar {date} holatiga · davr {from}–{to}',
    'Data as of {date} · period {from}–{to}',
  ],
  'an.search': [
    'Название, сокращение или город',
    'Nomi, qisqartmasi yoki shahar',
    'Name, acronym or city',
  ],
  'an.count': [
    'Организаций: {n}',
    'Tashkilotlar: {n}',
    'Organizations: {n}',
  ],
  'an.none': [
    'Ничего не найдено. Попробуйте другое название или сокращение.',
    'Hech narsa topilmadi. Boshqa nom yoki qisqartmani sinab ko‘ring.',
    'Nothing found. Try another name or acronym.',
  ],
  'an.country_card': [
    'Весь Узбекистан',
    'Butun O‘zbekiston',
    'All of Uzbekistan',
  ],
  'an.country_sub': [
    'Средние показатели по стране — для сравнения',
    'Mamlakat bo‘yicha o‘rtacha ko‘rsatkichlar — taqqoslash uchun',
    'Country-wide indicators — for comparison',
  ],
  'an.works_n': [
    'работ за {from}–{to}: {n}',
    '{from}–{to} yillardagi ishlar: {n}',
    'works {from}–{to}: {n}',
  ],
  // Ошибки.
  'an.err.network': [
    'Нет связи. Проверьте интернет и попробуйте ещё раз.',
    'Aloqa yo‘q. Internetni tekshirib, qayta urinib ko‘ring.',
    'No connection. Check your internet and try again.',
  ],
  'an.err.notready': [
    'Отчёты ещё не опубликованы. Они появятся после первого расчёта на GitHub.',
    'Hisobotlar hali e’lon qilinmagan. Ular GitHub’dagi birinchi hisob-kitobdan keyin paydo bo‘ladi.',
    'Reports aren’t published yet. They appear after the first run on GitHub.',
  ],
  'an.err.update': [
    'Формат отчётов обновился. Установите новую версию Scinode.',
    'Hisobotlar formati yangilandi. Scinode’ning yangi versiyasini o‘rnating.',
    'The report format changed. Please install the new version of Scinode.',
  ],
  'an.err.other': [
    'Не удалось загрузить отчёт. Попробуйте позже.',
    'Hisobotni yuklab bo‘lmadi. Keyinroq urinib ko‘ring.',
    'Couldn’t load the report. Please try later.',
  ],
  // Типы организаций.
  'an.type.education': ['Вуз', 'OTM', 'University'],
  'an.type.facility': [
    'Научный институт',
    'Ilmiy institut',
    'Research institute',
  ],
  'an.type.government': [
    'Государственная организация',
    'Davlat tashkiloti',
    'Government body',
  ],
  'an.type.healthcare': [
    'Медицинская организация',
    'Tibbiyot tashkiloti',
    'Healthcare',
  ],
  'an.type.archive': [
    'Архив, музей, институт',
    'Arxiv, muzey, institut',
    'Archive or museum',
  ],
  'an.type.nonprofit': [
    'Некоммерческая организация',
    'Notijorat tashkilot',
    'Nonprofit',
  ],
  'an.type.other': ['Другое', 'Boshqa', 'Other'],
  'an.type.country': ['Страна', 'Mamlakat', 'Country'],
  // Шапка отчёта.
  'an.stat.works': [
    'работ за {from}–{to}',
    'ish ({from}–{to})',
    'works {from}–{to}',
  ],
  'an.stat.h': ['индекс Хирша', 'Xirsh indeksi', 'h-index'],
  'an.stat.cites': [
    'цитирований всего',
    'jami iqtiboslar',
    'citations total',
  ],
  'an.disclaimer': [
    'Индикаторы рассчитаны по открытым данным OpenAlex; возможны неточности привязки авторов и организаций. Это не замена Scopus и Web of Science, а быстрая оценка по открытым данным.',
    'Ko‘rsatkichlar OpenAlex ochiq ma’lumotlari asosida hisoblangan; mualliflar va tashkilotlarni bog‘lashda xatolar bo‘lishi mumkin. Bu Scopus va Web of Science o‘rnini bosmaydi — ochiq ma’lumotlar bo‘yicha tezkor baho.',
    'Indicators are computed from open OpenAlex data; author and affiliation matching may be imperfect. This doesn’t replace Scopus or Web of Science — it’s a quick estimate from open data.',
  ],
  'an.compare': ['Сравнить', 'Taqqoslash', 'Compare'],
  'an.compare_pick': [
    'С какой организацией сравнить?',
    'Qaysi tashkilot bilan taqqoslash?',
    'Compare with which organization?',
  ],
  'an.open_site': ['Сайт', 'Sayt', 'Website'],
  // 1. Публикации по годам.
  'an.s.years': [
    'Публикации по годам',
    'Yillar bo‘yicha nashrlar',
    'Publications by year',
  ],
  'an.years_note': [
    '{year} — неполный год: работы ещё добавляются.',
    '{year} — to‘liq bo‘lmagan yil: ishlar hali qo‘shilmoqda.',
    '{year} is incomplete: works are still being added.',
  ],
  'an.l.article': ['Статьи', 'Maqolalar', 'Articles'],
  'an.l.conference': [
    'Материалы конференций',
    'Konferensiya materiallari',
    'Conference papers',
  ],
  'an.l.other': ['Другое', 'Boshqa', 'Other'],
  'an.year_total': [
    '{year}: всего {n}',
    '{year}: jami {n}',
    '{year}: {n} total',
  ],
  'an.tap_year': [
    'Нажмите на столбик, чтобы увидеть числа за год.',
    'Yil raqamlarini ko‘rish uchun ustunni bosing.',
    'Tap a bar to see that year’s numbers.',
  ],
  'an.types': ['Типы работ', 'Ish turlari', 'Work types'],
  'an.wt.article': ['Статья', 'Maqola', 'Article'],
  'an.wt.conference-paper': [
    'Доклад конференции',
    'Konferensiya ma’ruzasi',
    'Conference paper',
  ],
  'an.wt.book-chapter': ['Глава книги', 'Kitob bobi', 'Book chapter'],
  'an.wt.preprint': ['Препринт', 'Preprint', 'Preprint'],
  'an.wt.review': ['Обзор', 'Sharh', 'Review'],
  'an.wt.book': ['Книга', 'Kitob', 'Book'],
  'an.wt.dataset': ['Набор данных', 'Ma’lumotlar to‘plami', 'Dataset'],
  'an.wt.dissertation': ['Диссертация', 'Dissertatsiya', 'Dissertation'],
  'an.wt.letter': ['Письмо', 'Xat', 'Letter'],
  'an.wt.editorial': ['Редакционная', 'Tahririyat maqolasi', 'Editorial'],
  'an.wt.conference-abstract': [
    'Тезисы конференции',
    'Konferensiya tezislari',
    'Conference abstract',
  ],
  'an.wt.paratext': [
    'Служебный материал (оглавление, обложка)',
    'Xizmat materiali (mundarija, muqova)',
    'Front or back matter',
  ],
  'an.wt.erratum': ['Исправление', 'Tuzatish', 'Erratum'],
  'an.wt.retraction': ['Отзыв статьи', 'Maqolani qaytarib olish', 'Retraction'],
  'an.wt.report': ['Отчёт', 'Hisobot', 'Report'],
  'an.wt.standard': ['Стандарт', 'Standart', 'Standard'],
  'an.wt.peer-review': ['Рецензия', 'Taqriz', 'Peer review'],
  'an.wt.supplementary-materials': [
    'Дополнительные материалы',
    'Qo‘shimcha materiallar',
    'Supplementary materials',
  ],
  'an.wt.data-paper': [
    'Статья о данных',
    'Ma’lumotlar haqida maqola',
    'Data paper',
  ],
  'an.wt.reference-entry': [
    'Статья в справочнике',
    'Ma’lumotnoma maqolasi',
    'Reference entry',
  ],
  'an.wt.book-review': ['Рецензия на книгу', 'Kitob taqrizi', 'Book review'],
  'an.wt.other': ['Другое', 'Boshqa', 'Other'],
  // 2. Открытый доступ.
  'an.s.oa': ['Открытый доступ', 'Ochiq kirish', 'Open access'],
  'an.oa_share': [
    'работ можно читать бесплатно',
    'ishni bepul o‘qish mumkin',
    'of works are free to read',
  ],
  'an.oa_by_year': [
    'Доля открытых работ по годам',
    'Yillar bo‘yicha ochiq ishlar ulushi',
    'Open share by year',
  ],
  'an.oa.diamond': [
    'Бриллиантовый (журнал бесплатен и для авторов)',
    'Olmos (jurnal mualliflar uchun ham bepul)',
    'Diamond (free for authors too)',
  ],
  'an.oa.gold': [
    'Золотой (открытый журнал)',
    'Oltin (ochiq jurnal)',
    'Gold (open journal)',
  ],
  'an.oa.hybrid': [
    'Гибридный (открытая статья в платном журнале)',
    'Gibrid (pullik jurnaldagi ochiq maqola)',
    'Hybrid (open paper in a paid journal)',
  ],
  'an.oa.green': [
    'Зелёный (копия в репозитории)',
    'Yashil (repozitoriydagi nusxa)',
    'Green (copy in a repository)',
  ],
  'an.oa.bronze': [
    'Бронзовый (бесплатно на сайте, без лицензии)',
    'Bronza (saytda bepul, litsenziyasiz)',
    'Bronze (free on site, no license)',
  ],
  'an.oa.closed': ['Закрытый', 'Yopiq', 'Closed'],
  // 3. Цитирование.
  'an.s.cite': [
    'Уровень цитирования',
    'Iqtibos darajasi',
    'Citation impact',
  ],
  'an.cite_note': [
    'Сравнение с мировым уровнем своей области и года. Серая черта — мировой уровень, оранжевая — Узбекистан в целом.',
    'O‘z sohasi va yilining jahon darajasi bilan taqqoslash. Kulrang chiziq — jahon darajasi, to‘q sariq — butun O‘zbekiston.',
    'Compared with the world level for the same field and year. Grey mark — world level, orange — Uzbekistan overall.',
  ],
  'an.c.top10': [
    'Все работы с участием — в мировом топ-10 %',
    'Ishtirokidagi barcha ishlar — jahon top-10 % ida',
    'All co-authored works — in the world’s top 10%',
  ],
  'an.c.top1': [
    'В мировом топ-1 %',
    'Jahon top-1 % ida',
    'In the world’s top 1%',
  ],
  'an.c.cited': [
    'Процитированы хотя бы раз',
    'Kamida bir marta iqtibos keltirilgan',
    'Cited at least once',
  ],
  'an.c.above1': [
    'Цитируются выше мирового уровня (FWCI > 1)',
    'Jahon darajasidan yuqori iqtibos (FWCI > 1)',
    'Cited above world level (FWCI > 1)',
  ],
  'an.world': ['мир: {v}', 'jahon: {v}', 'world: {v}'],
  'an.country_v': ['страна: {v}', 'mamlakat: {v}', 'country: {v}'],
  // 4. Направления.
  'an.s.topics': [
    'Сильные направления',
    'Kuchli yo‘nalishlar',
    'Strong research areas',
  ],
  'an.topics_note': [
    'Разделы науки с наибольшим числом работ. «Сильное» — по собственным работам организации: их не меньше {n}, и доля в мировом топ-10 % надёжно выше 10 % (с учётом погрешности малых чисел). «В основном соавторство» — большая часть работ раздела ведут другие организации.',
    'Eng ko‘p ishlar bo‘lgan fan bo‘limlari. «Kuchli» — tashkilotning o‘z ishlari bo‘yicha: ular kamida {n} ta va jahon top-10 % idagi ulushi ishonchli ravishda 10 % dan yuqori (kichik sonlar xatoligi hisobga olingan). «Asosan hammualliflik» — bo‘lim ishlarining aksariyatini boshqa tashkilotlar olib boradi.',
    'Fields with the most works. “Strong” is judged on the organization’s own works: at least {n} of them, with a top-10% share reliably above 10% (allowing for small-number error). “Mostly co-authorship” means most works in the field are led by other organizations.',
  ],
  'an.strong': ['сильное', 'kuchli', 'strong'],
  'an.topic_row': [
    'в мировом топ-10 %: {p}',
    'jahon top-10 % ida: {p}',
    'in the world’s top 10%: {p}',
  ],
  'an.no_strong': [
    'Пока нет направлений выше мирового уровня — это нормально для растущих организаций.',
    'Hozircha jahon darajasidan yuqori yo‘nalishlar yo‘q — o‘sib borayotgan tashkilotlar uchun bu odatiy.',
    'No areas above world level yet — normal for growing organizations.',
  ],
  // 5. Партнёры.
  'an.s.partners': ['Партнёры', 'Hamkorlar', 'Partners'],
  'an.intl': [
    'работ с зарубежными соавторами',
    'ishlar xorijiy hammualliflar bilan',
    'of works with foreign co-authors',
  ],
  'an.countries': [
    'Страны-партнёры',
    'Hamkor mamlakatlar',
    'Partner countries',
  ],
  'an.partner_orgs': [
    'Организации-партнёры',
    'Hamkor tashkilotlar',
    'Partner organizations',
  ],
  // 6. Авторы.
  'an.s.authors': ['Ведущие авторы', 'Yetakchi mualliflar', 'Top authors'],
  'an.authors_note': [
    'По числу работ в этой организации за {from}–{to}. h-индекс и цитирования — за всю карьеру.',
    '{from}–{to} yillarda ushbu tashkilotdagi ishlar soni bo‘yicha. h-indeks va iqtiboslar — butun faoliyat davomida.',
    'By number of works at this organization in {from}–{to}. h-index and citations are career totals.',
  ],
  'an.author_row': [
    'работ здесь: {n} · h {h} · цитирований {c}',
    'bu yerdagi ishlar: {n} · h {h} · iqtiboslar {c}',
    'works here: {n} · h {h} · citations {c}',
  ],
  // 7. Журналы.
  'an.s.journals': ['Журналы', 'Jurnallar', 'Journals'],
  'an.doaj_share': [
    'работ в журналах из каталога DOAJ',
    'ishlar DOAJ katalogidagi jurnallarda',
    'of works in DOAJ-listed journals',
  ],
  'an.journals_note': [
    'DOAJ — каталог проверенных журналов открытого доступа. Отсутствие в DOAJ не значит, что журнал плохой, но повод проверить его внимательнее.',
    'DOAJ — tekshirilgan ochiq kirish jurnallari katalogi. DOAJ’da yo‘qligi jurnal yomon degani emas, lekin uni diqqat bilan tekshirish uchun sabab.',
    'DOAJ is a directory of vetted open-access journals. Not being listed doesn’t make a journal bad, but it’s a reason to check it carefully.',
  ],
  'an.jt.journal': ['журнал', 'jurnal', 'journal'],
  'an.jt.repository': ['репозиторий', 'repozitoriy', 'repository'],
  'an.jt.conference': ['конференция', 'konferensiya', 'conference'],
  'an.jt.ebook platform': [
    'книжная платформа',
    'kitob platformasi',
    'e-book platform'
  ],
  'an.jt.book series': ['книжная серия', 'kitob seriyasi', 'book series'],
  'an.journal_row': ['работ: {n}', 'ishlar: {n}', 'works: {n}'],
  // 8. Сравнение.
  'an.s.compare': [
    'Сравнение организаций',
    'Tashkilotlarni taqqoslash',
    'Compare organizations',
  ],
  'an.compare_hint': [
    'Сравните эту организацию с любой другой из списка.',
    'Ushbu tashkilotni ro‘yxatdagi boshqasi bilan taqqoslang.',
    'Compare this organization with any other on the list.',
  ],
  'an.cmp.works': [
    'Работ за {from}–{to}',
    '{from}–{to} yillardagi ishlar',
    'Works {from}–{to}',
  ],
  'an.cmp.articles': [
    'Из них журнальных статей',
    'Shundan jurnal maqolalari',
    'Of them journal articles',
  ],
  'an.cmp.oa': ['Открытый доступ', 'Ochiq kirish', 'Open access'],
  'an.cmp.intl': [
    'С зарубежными соавторами',
    'Xorijiy hammualliflar bilan',
    'With foreign co-authors',
  ],
  'an.cmp.doaj': ['В журналах DOAJ', 'DOAJ jurnallarida', 'In DOAJ journals'],
  'an.cmp.h': ['Индекс Хирша', 'Xirsh indeksi', 'h-index'],
  'an.cmp.strong': [
    'Сильных направлений',
    'Kuchli yo‘nalishlar',
    'Strong areas',
  ],
  'an.cmp.years': [
    'Публикации по годам',
    'Yillar bo‘yicha nashrlar',
    'Publications by year',
  ],
  // PDF-отчёт.
  'ap.pdf': ['PDF-отчёт', 'PDF hisobot', 'PDF report'],
  'ap.kind_org': [
    'ОТЧЁТ ПО ОРГАНИЗАЦИИ',
    'TASHKILOT HISOBOTI',
    'ORGANIZATION REPORT',
  ],
  'ap.kind_country': [
    'ОТЧЁТ ПО СТРАНЕ',
    'MAMLAKAT HISOBOTI',
    'COUNTRY REPORT',
  ],
  'ap.kind_compare': [
    'СРАВНЕНИЕ ОРГАНИЗАЦИЙ',
    'TASHKILOTLARNI TAQQOSLASH',
    'ORGANIZATION COMPARISON',
  ],
  'ap.type': ['Тип', 'Turi', 'Type'],
  'ap.city': ['Город', 'Shahar', 'City'],
  'ap.period': ['Период', 'Davr', 'Period'],
  'ap.data_date': ['Данные на', 'Ma’lumotlar sanasi', 'Data as of'],
  'ap.source': ['Источник', 'Manba', 'Source'],
  'ap.source_v': [
    'OpenAlex (открытые данные, CC0)',
    'OpenAlex (ochiq ma’lumotlar, CC0)',
    'OpenAlex (open data, CC0)',
  ],
  'ap.year': ['Год', 'Yil', 'Year'],
  'ap.total': ['Всего', 'Jami', 'Total'],
  'ap.share': ['Доля', 'Ulush', 'Share'],
  'ap.works': ['Работ', 'Ishlar', 'Works'],
  'ap.indicator': ['Показатель', 'Ko‘rsatkich', 'Indicator'],
  'ap.org': ['Организация', 'Tashkilot', 'Organization'],
  'ap.country': ['Страна', 'Mamlakat', 'Country'],
  'ap.world': ['Мир', 'Jahon', 'World'],
  'ap.area': ['Раздел науки', 'Fan bo‘limi', 'Research area'],
  'ap.yes': ['да', 'ha', 'yes'],
  'ap.own': ['Своих', 'O‘ziniki', 'Own'],
  'ap.own_top10': [
    'Свои в топ-10 %',
    'O‘ziniki top-10 % da',
    'Own in top 10%',
  ],
  'ap.mark': ['Отметка', 'Belgi', 'Note'],
  'ap.founded': ['Основан', 'Tashkil etilgan', 'Founded'],
  'ap.work': ['Работа', 'Ish', 'Work'],
  'ap.author': ['Автор', 'Muallif', 'Author'],
  'ap.here': ['Работ здесь', 'Bu yerdagi ishlar', 'Works here'],
  'ap.cites': ['Цитирований', 'Iqtiboslar', 'Citations'],
  'ap.source_name': [
    'Журнал или источник',
    'Jurnal yoki manba',
    'Journal or source'
  ],
  'ap.vs': ['и', 'va', 'vs'],
  'ap.file_compare': ['Сравнение', 'Taqqoslash', 'Comparison'],
  'an.c.lead_top10': [
    'Собственные работы в мировом топ-10 %',
    'O‘z ishlari jahon top-10 % ida',
    'Own works in the world’s top 10%',
  ],
  'an.lead_note': [
    'Собственные (ведущие) работы — где автор для переписки из этой организации: {n} из {all} ({p}). Они показывают её собственный уровень; в остальных работах организация — один из соавторов.',
    'O‘z (yetakchi) ishlari — muloqot uchun muallif shu tashkilotdan bo‘lgan ishlar: {all} tadan {n} ({p}). Ular tashkilotning o‘z darajasini ko‘rsatadi; qolganlarida tashkilot — hammualliflardan biri.',
    'Own (leading) works are those whose corresponding author is from this organization: {n} of {all} ({p}). They show its own level; in the rest it is one of the co-authors.',
  ],
  'an.mega_note': [
    'Статей больших коллабораций (больше 100 авторов): {n}, из них в топ-10 %: {t}. Без них доля всех работ в топ-10 % — {p}.',
    'Katta hamkorlik maqolalari (100 dan ortiq muallif): {n}, shundan top-10 % da: {t}. Ularsiz barcha ishlarning top-10 % dagi ulushi — {p}.',
    'Large-collaboration papers (over 100 authors): {n}, of them in the top 10%: {t}. Without them, the top-10% share of all works is {p}.',
  ],
  'an.guest': [
    'в основном соавторство',
    'asosan hammualliflik',
    'mostly co-authorship',
  ],
  'an.topic_row_lead': [
    'своих работ: {n} · из них в топ-10 %: {p}',
    'o‘z ishlari: {n} · top-10 % da: {p}',
    'own works: {n} · in top 10%: {p}',
  ],
  'an.s.integrity': [
    'Надёжность данных',
    'Ma’lumotlar ishonchliligi',
    'Data reliability',
  ],
  'an.retracted': [
    'отозванных статей за {from}–{to}',
    '{from}–{to} yillarda qaytarib olingan maqolalar',
    'retracted papers in {from}–{to}',
  ],
  'an.retracted_note': [
    'Отозванные статьи — снятые журналом из-за ошибок или нарушений (данные Retraction Watch через OpenAlex). Даже несколько таких статей — повод проверить, где и как публикуются сотрудники.',
    'Qaytarib olingan maqolalar — xato yoki qoidabuzarlik sababli jurnal olib tashlagan maqolalar (OpenAlex orqali Retraction Watch ma’lumotlari). Hatto bir nechtasi ham xodimlar qayerda va qanday nashr qilishini tekshirishga sabab.',
    'Retracted papers were withdrawn by journals for errors or misconduct (Retraction Watch data via OpenAlex). Even a few are a reason to check where and how staff publish.',
  ],
  'an.retracted_none': [
    'Отозванных статей за этот период нет.',
    'Bu davrda qaytarib olingan maqolalar yo‘q.',
    'No retracted papers in this period.',
  ],
  'an.repo_share': [
    'работ — только в репозиториях (Zenodo и др.), без журнала',
    'ishlar — faqat repozitoriylarda (Zenodo va boshq.), jurnalsiz',
    'of works are only in repositories (Zenodo etc.), not in a journal',
  ],
  'an.repo_note': [
    'Такие работы обычно не проходили рецензирование журнала.',
    'Bunday ishlar odatda jurnal taqrizidan o‘tmagan.',
    'Such works usually haven’t gone through journal peer review.',
  ],
  'an.cmp.retracted': [
    'Отозванных статей',
    'Qaytarib olingan maqolalar',
    'Retracted papers',
  ],
  'an.established': [
    'основан в {y}',
    '{y}-yilda tashkil etilgan',
    'founded {y}'
  ],
  'an.j.no_crossref': [
    'нет в Crossref (у статей нет DOI)',
    'Crossref’da yo‘q (maqolalarda DOI yo‘q)',
    'not in Crossref (no DOIs)',
  ],
  'an.j.growth': [
    'резкий рост: с {a} до {b} работ в год за 3 года (к {y})',
    'keskin o‘sish: 3 yilda yiliga {a} tadan {b} tagacha ish ({y} gacha)',
    'sharp growth: from {a} to {b} works a year over 3 years (to {y})',
  ],
  'an.j.check': ['проверить', 'tekshirish', 'check'],
  'an.cc.title': [
    'Проверка цитирования {n} самых цитируемых работ',
    'Eng ko‘p iqtibos keltirilgan {n} ta ishning iqtibos tekshiruvi',
    'Citation check of the {n} most cited works',
  ],
  'an.cc.note': [
    'Самоцитирование по данным OpenCitations (CC0), откуда приходят цитирования — по OpenAlex. Высокие доли — повод присмотреться к работе, а не обвинение: самоцитирование бывает и вполне законным.',
    'O‘z-o‘ziga iqtibos — OpenCitations (CC0) ma’lumotlari, iqtiboslar qayerdan kelishi — OpenAlex bo‘yicha. Yuqori ulushlar — ishga diqqat bilan qarash uchun sabab, ayblov emas: o‘z-o‘ziga iqtibos qonuniy ham bo‘lishi mumkin.',
    'Self-citation from OpenCitations (CC0); where citations come from, from OpenAlex. High shares are a reason to look closer, not an accusation: self-citation can be perfectly legitimate.',
  ],
  'an.cc.author_sc': [
    'Самоцитирование авторов',
    'Mualliflarning o‘z-o‘ziga iqtibosi',
    'Author self-citation',
  ],
  'an.cc.journal_sc': [
    'Ссылки из того же журнала',
    'Xuddi shu jurnaldan havolalar',
    'Citations from the same journal',
  ],
  'an.cc.own': [
    'Цитирования из своей же организации',
    'O‘z tashkilotidan iqtiboslar',
    'Citations from the same organization',
  ],
  'an.cc.none': [
    'Тревожных признаков не найдено.',
    'Xavotirli belgilar topilmadi.',
    'No warning signs found.',
  ],
  'an.cc.flagged': [
    'Работ с тревожными признаками: {n} из {all}',
    'Xavotirli belgili ishlar: {all} tadan {n}',
    'Works with warning signs: {n} of {all}',
  ],
  'an.cc.cited': ['цитирований: {n}', 'iqtiboslar: {n}', 'citations: {n}'],
  'an.cc.f.own_institution': [
    'цитируют свои',
    'o‘zlari iqtibos keltiradi',
    'cited by own organization',
  ],
  'an.cc.f.one_institution': [
    'почти все цитаты от одной организации',
    'deyarli barcha iqtiboslar bitta tashkilotdan',
    'mostly cited by one organization',
  ],
  'an.cc.f.author_self': [
    'самоцитирование авторов',
    'mualliflarning o‘z-o‘ziga iqtibosi',
    'author self-citation',
  ],
  'an.cc.f.journal_self': [
    'ссылки из того же журнала',
    'xuddi shu jurnaldan havolalar',
    'same-journal citations',
  ],
  'an.cmp.flagged': [
    'Работ с тревожными признаками',
    'Xavotirli belgili ishlar',
    'Works with warning signs',
  ],
  // Методика.
  'an.s.method': ['Методика', 'Metodika', 'Methodology'],
  'an.method': [
    'Источник — OpenAlex (данные CC0), выгрузка {date}. Работы организации считаются вместе с её подразделениями. Показатели качества — за 5 последних полных лет ({from}–{to}). Топ-10 % и топ-1 % — процентиль цитирования в своей области и году, как в Лейденском рейтинге (CWTS). Собственные работы — где автор для переписки из организации. «Сильные» направления — по собственным работам с поправкой на погрешность малых чисел (интервал Уилсона). Отдельно показаны статьи больших коллабораций (больше 100 авторов), отозванные статьи (Retraction Watch), самоцитирование самых цитируемых работ (OpenCitations), журналы вне Crossref и с резким ростом объёма. Официальные названия — из реестра ROR. FWCI — нормированная цитируемость, 1 — мировой уровень. В список входят организации от {min} работ за этот период.',
    'Manba — OpenAlex (CC0 ma’lumotlari), {date} holatiga. Tashkilot ishlari uning bo‘linmalari bilan birga hisoblanadi. Sifat ko‘rsatkichlari — oxirgi 5 to‘liq yil ({from}–{to}). Top-10 % va top-1 % — o‘z sohasi va yilidagi iqtibos persentili, Leyden reytingi (CWTS) kabi. O‘z ishlari — muloqot uchun muallif tashkilotdan bo‘lgan ishlar. «Kuchli» yo‘nalishlar — o‘z ishlari bo‘yicha, kichik sonlar xatoligi hisobga olingan holda (Uilson intervali). Katta hamkorlik maqolalari (100 dan ortiq muallif), qaytarib olingan maqolalar (Retraction Watch), eng ko‘p iqtibos keltirilgan ishlarning o‘z-o‘ziga iqtibosi (OpenCitations), Crossref’dan tashqaridagi va hajmi keskin o‘sgan jurnallar alohida ko‘rsatilgan. Rasmiy nomlar — ROR reyestridan. FWCI — me’yorlangan iqtiboslilik, 1 — jahon darajasi. Ro‘yxatga shu davrda kamida {min} ishi bor tashkilotlar kiradi.',
    'Source: OpenAlex (CC0 data), as of {date}. An organization’s works include its sub-units. Quality indicators cover the last 5 full years ({from}–{to}). Top 10% and top 1% use the citation percentile within field and year, as in the Leiden Ranking (CWTS). Own works are those with a corresponding author from the organization. “Strong” areas are judged on own works, allowing for small-number error (Wilson interval). Large-collaboration papers (over 100 authors), retracted papers (Retraction Watch), self-citation of the most cited works (OpenCitations), and journals outside Crossref or with sharp volume growth are shown separately. Official names come from the ROR registry. FWCI is field-normalized citation impact, 1 = world level. Organizations with at least {min} works in the period are included.',
  ],
  'an.method_link': [
    'Подробнее о методике',
    'Metodika haqida batafsil',
    'More about the methodology',
  ],

  // --- ЦУР, языки, финансирование, APC, плодовитость (ноябрь 2026) ---
  'an.s.sdg': [
    'Цели устойчивого развития ООН',
    'BMTning Barqaror rivojlanish maqsadlari',
    'UN Sustainable Development Goals',
  ],
  'an.sdg_share': [
    'работ связаны хотя бы с одной целью',
    'ishlar kamida bitta maqsad bilan bog‘liq',
    'of works relate to at least one goal',
  ],
  'an.sdg_note': [
    'OpenAlex относит работу к цели автоматически — по названию и аннотации. Одна работа может относиться к нескольким целям, доли считаются от работ с целями. Пригодится для рейтинга THE Impact и отчётов о вкладе в ЦУР.',
    'OpenAlex ishni maqsadga avtomatik — sarlavha va annotatsiya bo‘yicha bog‘laydi. Bitta ish bir nechta maqsadga tegishli bo‘lishi mumkin, ulushlar maqsadli ishlardan hisoblanadi. THE Impact reytingi va BRM hisobotlari uchun foydali.',
    'OpenAlex assigns goals automatically from titles and abstracts. A work can relate to several goals; shares are of works with any goal. Useful for THE Impact Rankings and SDG reports.',
  ],
  'an.sdg.1': [
    'Ликвидация нищеты',
    'Qashshoqlikka barham berish',
    'No poverty'
  ],
  'an.sdg.2': ['Ликвидация голода', 'Ochlikka barham berish', 'Zero hunger'],
  'an.sdg.3': [
    'Хорошее здоровье и благополучие',
    'Sog‘liq va farovonlik',
    'Good health and well-being',
  ],
  'an.sdg.4': [
    'Качественное образование',
    'Sifatli ta’lim',
    'Quality education'
  ],
  'an.sdg.5': ['Гендерное равенство', 'Gender tengligi', 'Gender equality'],
  'an.sdg.6': [
    'Чистая вода и санитария',
    'Toza suv va sanitariya',
    'Clean water and sanitation',
  ],
  'an.sdg.7': [
    'Недорогостоящая и чистая энергия',
    'Arzon va toza energiya',
    'Affordable and clean energy',
  ],
  'an.sdg.8': [
    'Достойная работа и экономический рост',
    'Munosib mehnat va iqtisodiy o‘sish',
    'Decent work and economic growth',
  ],
  'an.sdg.9': [
    'Индустриализация, инновации и инфраструктура',
    'Sanoat, innovatsiyalar va infratuzilma',
    'Industry, innovation and infrastructure',
  ],
  'an.sdg.10': [
    'Уменьшение неравенства',
    'Tengsizlikni qisqartirish',
    'Reduced inequalities',
  ],
  'an.sdg.11': [
    'Устойчивые города и населённые пункты',
    'Barqaror shaharlar va aholi punktlari',
    'Sustainable cities and communities',
  ],
  'an.sdg.12': [
    'Ответственное потребление и производство',
    'Mas’uliyatli iste’mol va ishlab chiqarish',
    'Responsible consumption and production',
  ],
  'an.sdg.13': [
    'Борьба с изменением климата',
    'Iqlim o‘zgarishiga qarshi kurash',
    'Climate action',
  ],
  'an.sdg.14': [
    'Сохранение морских экосистем',
    'Dengiz ekotizimlarini saqlash',
    'Life below water',
  ],
  'an.sdg.15': [
    'Сохранение экосистем суши',
    'Quruqlik ekotizimlarini saqlash',
    'Life on land',
  ],
  'an.sdg.16': [
    'Мир, правосудие и эффективные институты',
    'Tinchlik, odil sudlov va samarali institutlar',
    'Peace, justice and strong institutions',
  ],
  'an.sdg.17': [
    'Партнёрство в интересах устойчивого развития',
    'Barqaror rivojlanish yo‘lida hamkorlik',
    'Partnerships for the goals',
  ],
  'an.s.lang': [
    'Языки публикаций',
    'Nashrlar tillari',
    'Publication languages'
  ],
  'an.lang_note': [
    'Язык OpenAlex определяет автоматически по названию и аннотации и иногда ошибается, особенно на коротких текстах.',
    'Tilni OpenAlex sarlavha va annotatsiya bo‘yicha avtomatik aniqlaydi va ba’zan, ayniqsa qisqa matnlarda, xato qiladi.',
    'OpenAlex detects the language automatically from titles and abstracts and sometimes errs, especially on short texts.',
  ],
  'an.lang.en': ['Английский', 'Ingliz', 'English'],
  'an.lang.uz': ['Узбекский', 'O‘zbek', 'Uzbek'],
  'an.lang.ru': ['Русский', 'Rus', 'Russian'],
  'an.lang.tr': ['Турецкий', 'Turk', 'Turkish'],
  'an.lang.tg': ['Таджикский', 'Tojik', 'Tajik'],
  'an.lang.kk': ['Казахский', 'Qozoq', 'Kazakh'],
  'an.lang.ky': ['Киргизский', 'Qirg‘iz', 'Kyrgyz'],
  'an.lang.az': ['Азербайджанский', 'Ozarbayjon', 'Azerbaijani'],
  'an.lang.de': ['Немецкий', 'Nemis', 'German'],
  'an.lang.fr': ['Французский', 'Fransuz', 'French'],
  'an.lang.es': ['Испанский', 'Ispan', 'Spanish'],
  'an.lang.pt': ['Португальский', 'Portugal', 'Portuguese'],
  'an.lang.zh': ['Китайский', 'Xitoy', 'Chinese'],
  'an.lang.ar': ['Арабский', 'Arab', 'Arabic'],
  'an.lang.fa': ['Персидский', 'Fors', 'Persian'],
  'an.lang.uk': ['Украинский', 'Ukrain', 'Ukrainian'],
  'an.lang.bg': ['Болгарский', 'Bolgar', 'Bulgarian'],
  'an.lang.pl': ['Польский', 'Polyak', 'Polish'],
  'an.lang.lv': ['Латышский', 'Latish', 'Latvian'],
  'an.lang.id': ['Индонезийский', 'Indonez', 'Indonesian'],
  'an.lang.it': ['Итальянский', 'Italyan', 'Italian'],
  'an.lang.nl': ['Нидерландский', 'Niderland', 'Dutch'],
  'an.lang.ja': ['Японский', 'Yapon', 'Japanese'],
  'an.lang.ko': ['Корейский', 'Koreys', 'Korean'],
  'an.lang.hi': ['Хинди', 'Hind', 'Hindi'],
  'an.lang.tk': ['Туркменский', 'Turkman', 'Turkmen'],
  'an.s.funding': [
    'Финансирование и расходы',
    'Moliyalashtirish va xarajatlar',
    'Funding and costs',
  ],
  'an.funded_share': [
    'работ с указанным фондом',
    'jamg‘arma ko‘rsatilgan ishlar',
    'of works name a funder',
  ],
  'an.funding_note': [
    'Фонды берутся из благодарностей в статьях и данных издателей (Crossref). Многие журналы их не передают, поэтому настоящая доля выше.',
    'Jamg‘armalar maqolalardagi minnatdorchiliklar va noshirlar ma’lumotlaridan (Crossref) olinadi. Ko‘p jurnallar ularni bermaydi, shuning uchun haqiqiy ulush yuqoriroq.',
    'Funders come from acknowledgements and publisher data (Crossref). Many journals do not supply them, so the real share is higher.',
  ],
  'an.funders': ['Главные фонды', 'Asosiy jamg‘armalar', 'Main funders'],
  'an.apc_lead': [
    'оценка платы за публикацию (APC) по собственным работам · {n} работ',
    'o‘z ishlari bo‘yicha nashr to‘lovi (APC) bahosi · {n} ta ish',
    'estimated publication fees (APC) for own works · {n} works',
  ],
  'an.apc_all': [
    'оценка платы за публикацию (APC) по всем работам · {n} работ',
    'barcha ishlar bo‘yicha nashr to‘lovi (APC) bahosi · {n} ta ish',
    'estimated publication fees (APC) for all works · {n} works',
  ],
  'an.apc_note': [
    'Сумма по прайс-листам журналов для статей в открытом доступе (золотом и гибридном), данные OpenAlex. Это оценка сверху: скидки, гранты и освобождения от оплаты не учтены. Обычно платит организация автора для переписки, поэтому для вуза главная цифра — по собственным работам.',
    'Ochiq (oltin va gibrid) kirishdagi maqolalar uchun jurnallar narxlari bo‘yicha summa, OpenAlex ma’lumotlari. Bu yuqori baho: chegirmalar, grantlar va to‘lovdan ozod qilish hisobga olinmagan. Odatda yozishma muallifining tashkiloti to‘laydi, shuning uchun OTM uchun asosiy raqam — o‘z ishlari bo‘yicha.',
    'Sum of journal list prices for gold and hybrid open-access papers (OpenAlex). An upper estimate: discounts, grants and waivers are not counted. Usually the corresponding author’s organization pays, so for a university the key figure is for its own works.',
  ],
  'an.apc_country_note': [
    'Для страны — по всем работам с участием авторов из Узбекистана, включая те, где платили соавторы из других стран.',
    'Mamlakat uchun — O‘zbekiston mualliflari ishtirokidagi barcha ishlar, jumladan boshqa mamlakat hammualliflari to‘lagan ishlar.',
    'For the country: all works with authors from Uzbekistan, including those paid for by co-authors abroad.',
  ],
  'an.prolific': [
    '— столько авторов публикуют больше {t} работ в год',
    'ta muallif yiliga {t} tadan ortiq ish nashr qiladi',
    '— number of authors with over {t} works a year',
  ],
  'an.prolific_note': [
    'Больше 72 статей, обзоров и докладов за год — одна работа каждые 5 дней (порог Иоаннидиса, Nature, 2018). Считаются все места работы автора, работы больше чем со 100 авторами не учитываются. Это повод проверить, а не обвинение: бывают большие лаборатории, а OpenAlex иногда склеивает разных людей с одним именем. Проверены {n} самых активных авторов.',
    'Yiliga 72 tadan ortiq maqola, sharh va ma’ruza — har 5 kunda bitta ish (Ioannidis chegarasi, Nature, 2018). Muallifning barcha ish joylari hisoblanadi, 100 dan ortiq muallifli ishlar hisobga olinmaydi. Bu ayblov emas, tekshirish uchun sabab: katta laboratoriyalar bo‘ladi, OpenAlex esa ba’zan bir xil ismli turli odamlarni birlashtiradi. Eng faol {n} ta muallif tekshirildi.',
    'Over 72 articles, reviews and conference papers a year is one every 5 days (Ioannidis threshold, Nature, 2018). All of the author’s affiliations count; works with more than 100 authors are excluded. A reason to check, not an accusation: large labs exist, and OpenAlex sometimes merges different people with the same name. The {n} most active authors were checked.',
  ],
  'an.prolific_none': [
    'Среди самых активных авторов никто не превысил порог.',
    'Eng faol mualliflar orasida hech kim chegaradan oshmadi.',
    'None of the most active authors exceeded the threshold.',
  ],
  'an.prolific_row': [
    'до {max} работ в {y} году · лет выше порога: {k} · здесь {n} за период',
    '{y} yilda {max} tagacha ish · chegaradan yuqori yillar: {k} · bu yerda davrda {n}',
    'up to {max} works in {y} · years over threshold: {k} · {n} here in the period',
  ],
  'an.cmp.sdg': ['Связаны с ЦУР', 'BRM bilan bog‘liq', 'Related to SDGs'],
  'an.cmp.uz': ['На узбекском языке', 'O‘zbek tilida', 'In Uzbek'],
  'an.cmp.funded': [
    'С указанным фондом',
    'Jamg‘arma ko‘rsatilgan',
    'Name a funder',
  ],
  'an.cmp.apc': [
    'Оценка APC, свои работы',
    'APC bahosi, o‘z ishlari',
    'Estimated APC, own works',
  ],
  'an.cmp.prolific': [
    'Авторов больше 72 работ в год',
    'Yiliga 72 tadan ortiq ishli mualliflar',
    'Authors with over 72 works a year',
  ],
};
