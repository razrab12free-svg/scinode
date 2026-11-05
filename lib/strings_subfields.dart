// Названия 252 разделов OpenAlex (ru, uz) и поисковые синонимы.
// Английские названия — в assets/taxonomy/openalex_v2.json.
const Map<String, List<String>> subfieldNamesLocal = {
  '1100': [
    'Сельскохозяйственные и биологические науки (общее)',
    'Qishloq xo‘jaligi va biologiya fanlari (umumiy)'
  ],
  '1102': ['Агрономия и растениеводство', 'Agronomiya va o‘simlikshunoslik'],
  '1103': ['Зоотехния и зоология', 'Zootexniya va zoologiya'],
  '1104': ['Гидробиология', 'Gidrobiologiya'],
  '1105': [
    'Экология, эволюция, поведение и систематика',
    'Ekologiya, evolyutsiya, xulq-atvor va sistematika'
  ],
  '1106': [
    'Пищевые науки и технологии',
    'Oziq-ovqat fanlari va texnologiyalari'
  ],
  '1107': ['Лесное хозяйство', 'O‘rmon xo‘jaligi'],
  '1108': ['Садоводство', 'Bog‘dorchilik'],
  '1109': ['Энтомология', 'Entomologiya'],
  '1110': [
    'Ботаника и науки о растениях',
    'Botanika va o‘simliklar haqidagi fanlar'
  ],
  '1111': ['Почвоведение', 'Tuproqshunoslik'],
  '1200': [
    'Гуманитарные науки и искусство (общее)',
    'Gumanitar fanlar va san’at (umumiy)'
  ],
  '1202': ['История', 'Tarix'],
  '1203': ['Языкознание и лингвистика', 'Tilshunoslik va lingvistika'],
  '1204': ['Археология', 'Arxeologiya'],
  '1205': [
    'Классическая филология и античность',
    'Klassik filologiya va antik davr'
  ],
  '1206': ['Сохранение культурного наследия', 'Madaniy merosni asrash'],
  '1207': ['История и философия науки', 'Fan tarixi va falsafasi'],
  '1208': [
    'Литературоведение и теория литературы',
    'Adabiyotshunoslik va adabiyot nazariyasi'
  ],
  '1209': ['Музееведение', 'Muzeyshunoslik'],
  '1210': ['Музыка и музыковедение', 'Musiqa va musiqashunoslik'],
  '1211': ['Философия', 'Falsafa'],
  '1212': ['Религиоведение', 'Dinshunoslik'],
  '1213': [
    'Изобразительное и исполнительское искусство',
    'Tasviriy va ijro san’ati'
  ],
  '1302': ['Старение (геронтология)', 'Qarish (gerontologiya)'],
  '1303': ['Биохимия', 'Biokimyo'],
  '1304': ['Биофизика', 'Biofizika'],
  '1305': ['Биотехнология', 'Biotexnologiya'],
  '1306': ['Исследования рака', 'Saraton tadqiqotlari'],
  '1307': ['Клеточная биология', 'Hujayra biologiyasi'],
  '1308': ['Клиническая биохимия', 'Klinik biokimyo'],
  '1309': ['Биология развития', 'Rivojlanish biologiyasi'],
  '1310': ['Эндокринология', 'Endokrinologiya'],
  '1311': ['Генетика', 'Genetika'],
  '1312': ['Молекулярная биология', 'Molekulyar biologiya'],
  '1313': ['Молекулярная медицина', 'Molekulyar tibbiyot'],
  '1314': ['Физиология', 'Fiziologiya'],
  '1315': ['Структурная биология', 'Struktur biologiya'],
  '1402': ['Бухгалтерский учёт', 'Buxgalteriya hisobi'],
  '1403': ['Бизнес и международный менеджмент', 'Biznes va xalqaro menejment'],
  '1404': [
    'Управленческие информационные системы',
    'Boshqaruv axborot tizimlari'
  ],
  '1405': [
    'Управление технологиями и инновациями',
    'Texnologiya va innovatsiyalarni boshqarish'
  ],
  '1406': ['Маркетинг', 'Marketing'],
  '1407': [
    'Организационное поведение и управление персоналом',
    'Tashkiliy xulq-atvor va kadrlarni boshqarish'
  ],
  '1408': ['Стратегия и менеджмент', 'Strategiya va menejment'],
  '1409': [
    'Туризм, досуг и гостиничный бизнес',
    'Turizm, dam olish va mehmonxona xo‘jaligi'
  ],
  '1410': ['Трудовые отношения', 'Mehnat munosabatlari'],
  '1502': ['Биоинженерия', 'Biomuhandislik'],
  '1503': ['Катализ', 'Kataliz'],
  '1504': [
    'Химическая безопасность и охрана здоровья',
    'Kimyoviy xavfsizlik va salomatlikni muhofaza qilish'
  ],
  '1506': ['Фильтрация и разделение', 'Filtrlash va ajratish'],
  '1507': [
    'Течение жидкостей и процессы переноса',
    'Suyuqlik oqimi va ko‘chirish jarayonlari'
  ],
  '1508': [
    'Химическая технология и процессы',
    'Kimyoviy texnologiya va jarayonlar'
  ],
  '1602': ['Аналитическая химия', 'Analitik kimyo'],
  '1603': ['Электрохимия', 'Elektrokimyo'],
  '1604': ['Неорганическая химия', 'Anorganik kimyo'],
  '1605': ['Органическая химия', 'Organik kimyo'],
  '1606': ['Физическая и теоретическая химия', 'Fizik va nazariy kimyo'],
  '1607': ['Спектроскопия', 'Spektroskopiya'],
  '1702': ['Искусственный интеллект', 'Sun’iy intellekt'],
  '1703': [
    'Теория вычислений и математика',
    'Hisoblash nazariyasi va matematika'
  ],
  '1704': [
    'Компьютерная графика и САПР',
    'Kompyuter grafikasi va avtomatlashtirilgan loyihalash'
  ],
  '1705': ['Компьютерные сети и связь', 'Kompyuter tarmoqlari va aloqa'],
  '1706': ['Прикладная информатика', 'Amaliy informatika'],
  '1707': [
    'Компьютерное зрение и распознавание образов',
    'Kompyuter ko‘rishi va obrazlarni tanish'
  ],
  '1708': [
    'Аппаратное обеспечение и архитектура ЭВМ',
    'Apparat ta’minoti va kompyuter arxitekturasi'
  ],
  '1709': [
    'Взаимодействие человека и компьютера',
    'Inson va kompyuter o‘zaro ta’siri'
  ],
  '1710': ['Информационные системы', 'Axborot tizimlari'],
  '1711': ['Обработка сигналов', 'Signallarni qayta ishlash'],
  '1712': ['Программное обеспечение', 'Dasturiy ta’minot'],
  '1800': [
    'Науки о принятии решений (общее)',
    'Qaror qabul qilish fanlari (umumiy)'
  ],
  '1802': [
    'Информационные системы и управление',
    'Axborot tizimlari va boshqaruv'
  ],
  '1803': [
    'Наука об управлении и исследование операций',
    'Boshqaruv fani va operatsiyalarni tadqiq qilish'
  ],
  '1804': [
    'Статистика, вероятность и неопределённость',
    'Statistika, ehtimollik va noaniqlik'
  ],
  '1902': ['Науки об атмосфере', 'Atmosfera fanlari'],
  '1904': ['Процессы на поверхности Земли', 'Yer yuzasi jarayonlari'],
  '1906': ['Геохимия и петрология', 'Geokimyo va petrologiya'],
  '1907': ['Геология', 'Geologiya'],
  '1908': ['Геофизика', 'Geofizika'],
  '1910': ['Океанология', 'Okeanologiya'],
  '1911': ['Палеонтология', 'Paleontologiya'],
  '1912': ['Космические и планетные науки', 'Kosmos va sayyoralar fanlari'],
  '2000': [
    'Экономика, эконометрика и финансы (общее)',
    'Iqtisodiyot, ekonometrika va moliya (umumiy)'
  ],
  '2002': ['Экономика и эконометрика', 'Iqtisodiyot va ekonometrika'],
  '2003': ['Финансы', 'Moliya'],
  '2100': ['Энергетика (общее)', 'Energetika (umumiy)'],
  '2102': [
    'Энергетическое машиностроение и электроэнергетика',
    'Energetika muhandisligi va elektr energetikasi'
  ],
  '2103': ['Топливные технологии', 'Yoqilg‘i texnologiyalari'],
  '2104': ['Ядерная энергетика и техника', 'Yadro energetikasi va texnikasi'],
  '2105': [
    'Возобновляемая энергетика, устойчивость и окружающая среда',
    'Qayta tiklanadigan energetika, barqarorlik va atrof-muhit'
  ],
  '2200': ['Технические науки (общее)', 'Texnika fanlari (umumiy)'],
  '2202': [
    'Авиационная и ракетно-космическая техника',
    'Aviatsiya va raketa-kosmik texnikasi'
  ],
  '2203': ['Автомобилестроение', 'Avtomobilsozlik'],
  '2204': ['Биомедицинская инженерия', 'Biotibbiyot muhandisligi'],
  '2205': [
    'Строительство и строительные конструкции',
    'Qurilish va qurilish konstruksiyalari'
  ],
  '2206': ['Вычислительная механика', 'Hisoblash mexanikasi'],
  '2207': ['Управление и системотехника', 'Boshqaruv va tizimlar muhandisligi'],
  '2208': ['Электротехника и электроника', 'Elektrotexnika va elektronika'],
  '2209': [
    'Промышленное и производственное машиностроение',
    'Sanoat va ishlab chiqarish muhandisligi'
  ],
  '2210': ['Машиностроение', 'Mashinasozlik'],
  '2211': ['Механика материалов', 'Materiallar mexanikasi'],
  '2212': ['Морская техника', 'Dengiz texnikasi'],
  '2213': [
    'Безопасность, риск, надёжность и качество',
    'Xavfsizlik, xavf, ishonchlilik va sifat'
  ],
  '2214': ['Медиатехнологии', 'Media texnologiyalari'],
  '2215': ['Здания и сооружения', 'Binolar va inshootlar'],
  '2216': ['Архитектура', 'Arxitektura'],
  '2302': ['Экологическое моделирование', 'Ekologik modellashtirish'],
  '2303': ['Экология', 'Ekologiya'],
  '2304': ['Химия окружающей среды', 'Atrof-muhit kimyosi'],
  '2305': ['Инженерная экология', 'Ekologik muhandislik'],
  '2306': [
    'Глобальные и планетарные изменения',
    'Global va sayyoraviy o‘zgarishlar'
  ],
  '2307': [
    'Здоровье, токсикология и мутагенез',
    'Salomatlik, toksikologiya va mutagenez'
  ],
  '2308': [
    'Экологический мониторинг, политика и право',
    'Ekologik monitoring, siyosat va huquq'
  ],
  '2309': [
    'Охрана природы и ландшафтов',
    'Tabiat va landshaftlarni muhofaza qilish'
  ],
  '2310': ['Загрязнение окружающей среды', 'Atrof-muhit ifloslanishi'],
  '2311': [
    'Обращение с отходами и их утилизация',
    'Chiqindilarni boshqarish va utilizatsiya qilish'
  ],
  '2312': ['Водные науки и технологии', 'Suv fanlari va texnologiyalari'],
  '2402': [
    'Прикладная микробиология и биотехнология',
    'Amaliy mikrobiologiya va biotexnologiya'
  ],
  '2403': ['Иммунология', 'Immunologiya'],
  '2404': ['Микробиология', 'Mikrobiologiya'],
  '2405': ['Паразитология', 'Parazitologiya'],
  '2406': ['Вирусология', 'Virusologiya'],
  '2500': ['Материаловедение (общее)', 'Materialshunoslik (umumiy)'],
  '2502': ['Биоматериалы', 'Biomateriallar'],
  '2503': ['Керамика и композиты', 'Keramika va kompozitlar'],
  '2504': [
    'Электронные, оптические и магнитные материалы',
    'Elektron, optik va magnit materiallar'
  ],
  '2505': ['Химия материалов', 'Materiallar kimyosi'],
  '2506': ['Металлы и сплавы', 'Metallar va qotishmalar'],
  '2507': ['Полимеры и пластмассы', 'Polimerlar va plastmassalar'],
  '2508': [
    'Поверхности, покрытия и плёнки',
    'Sirtlar, qoplamalar va plyonkalar'
  ],
  '2602': ['Алгебра и теория чисел', 'Algebra va sonlar nazariyasi'],
  '2604': ['Прикладная математика', 'Amaliy matematika'],
  '2605': ['Вычислительная математика', 'Hisoblash matematikasi'],
  '2607': [
    'Дискретная математика и комбинаторика',
    'Diskret matematika va kombinatorika'
  ],
  '2608': ['Геометрия и топология', 'Geometriya va topologiya'],
  '2610': ['Математическая физика', 'Matematik fizika'],
  '2611': ['Моделирование и симуляция', 'Modellashtirish va simulyatsiya'],
  '2612': ['Численный анализ', 'Sonli tahlil'],
  '2613': [
    'Статистика и теория вероятностей',
    'Statistika va ehtimollar nazariyasi'
  ],
  '2614': ['Теоретическая информатика', 'Nazariy informatika'],
  '2702': ['Анатомия', 'Anatomiya'],
  '2703': [
    'Анестезиология и лечение боли',
    'Anesteziologiya va og‘riqni davolash'
  ],
  '2704': ['Биохимия (медицина)', 'Biokimyo (tibbiyot)'],
  '2705': [
    'Кардиология и сердечно-сосудистая медицина',
    'Kardiologiya va yurak-qon tomir tibbiyoti'
  ],
  '2706': [
    'Реаниматология и интенсивная терапия',
    'Reanimatologiya va intensiv terapiya'
  ],
  '2707': [
    'Комплементарная и альтернативная медицина',
    'Komplementar va muqobil tibbiyot'
  ],
  '2708': ['Дерматология', 'Dermatologiya'],
  '2711': ['Неотложная медицина', 'Shoshilinch tibbiyot'],
  '2712': [
    'Эндокринология, диабет и обмен веществ',
    'Endokrinologiya, diabet va moddalar almashinuvi'
  ],
  '2713': ['Эпидемиология', 'Epidemiologiya'],
  '2714': ['Семейная медицина', 'Oilaviy tibbiyot'],
  '2715': ['Гастроэнтерология', 'Gastroenterologiya'],
  '2716': ['Генетика (медицина)', 'Genetika (tibbiyot)'],
  '2717': ['Гериатрия и геронтология', 'Geriatriya va gerontologiya'],
  '2718': ['Медицинская информатика', 'Tibbiy informatika'],
  '2720': ['Гематология', 'Gematologiya'],
  '2721': ['Гепатология', 'Gepatologiya'],
  '2723': ['Иммунология и аллергология', 'Immunologiya va allergologiya'],
  '2724': ['Внутренние болезни (терапия)', 'Ichki kasalliklar (terapiya)'],
  '2725': ['Инфекционные болезни', 'Yuqumli kasalliklar'],
  '2726': ['Микробиология (медицина)', 'Mikrobiologiya (tibbiyot)'],
  '2727': ['Нефрология', 'Nefrologiya'],
  '2728': ['Неврология (клиническая)', 'Nevrologiya (klinik)'],
  '2729': ['Акушерство и гинекология', 'Akusherlik va ginekologiya'],
  '2730': ['Онкология', 'Onkologiya'],
  '2731': ['Офтальмология', 'Oftalmologiya'],
  '2732': ['Ортопедия и спортивная медицина', 'Ortopediya va sport tibbiyoti'],
  '2733': ['Оториноларингология', 'Otorinolaringologiya'],
  '2734': ['Патология и судебная медицина', 'Patologiya va sud tibbiyoti'],
  '2735': [
    'Педиатрия, перинатология и здоровье детей',
    'Pediatriya, perinatologiya va bolalar salomatligi'
  ],
  '2736': ['Фармакология (медицина)', 'Farmakologiya (tibbiyot)'],
  '2737': ['Физиология (медицина)', 'Fiziologiya (tibbiyot)'],
  '2738': [
    'Психиатрия и психическое здоровье',
    'Psixiatriya va ruhiy salomatlik'
  ],
  '2739': [
    'Общественное здоровье, гигиена и медицина труда',
    'Jamoat salomatligi, gigiyena va mehnat tibbiyoti'
  ],
  '2740': ['Пульмонология', 'Pulmonologiya'],
  '2741': [
    'Радиология, ядерная медицина и визуализация',
    'Radiologiya, yadro tibbiyoti va vizualizatsiya'
  ],
  '2742': ['Реабилитация', 'Reabilitatsiya'],
  '2743': ['Репродуктивная медицина', 'Reproduktiv tibbiyot'],
  '2745': ['Ревматология', 'Revmatologiya'],
  '2746': ['Хирургия', 'Jarrohlik'],
  '2747': ['Трансплантология', 'Transplantologiya'],
  '2748': ['Урология', 'Urologiya'],
  '2802': ['Поведенческая нейронаука', 'Xulq-atvor neyrofani'],
  '2803': ['Биологическая психиатрия', 'Biologik psixiatriya'],
  '2804': [
    'Клеточная и молекулярная нейронаука',
    'Hujayra va molekulyar neyrofan'
  ],
  '2805': ['Когнитивная нейронаука', 'Kognitiv neyrofan'],
  '2806': ['Нейронаука развития', 'Rivojlanish neyrofani'],
  '2807': [
    'Эндокринная и вегетативная системы',
    'Endokrin va vegetativ tizimlar'
  ],
  '2808': ['Неврология (нейронаука)', 'Nevrologiya (neyrofan)'],
  '2809': ['Сенсорные системы', 'Sensor tizimlar'],
  '2910': [
    'Сестринское дело: этика и правовые вопросы',
    'Hamshiralik ishi: etika va huquqiy masalalar'
  ],
  '2911': [
    'Сестринское дело: руководство и управление',
    'Hamshiralik ishi: rahbarlik va boshqaruv'
  ],
  '2916': ['Питание и диетология', 'Ovqatlanish va dietologiya'],
  '2922': [
    'Сестринское дело: исследования и теория',
    'Hamshiralik ishi: tadqiqot va nazariya'
  ],
  '3002': ['Разработка лекарств', 'Dori vositalarini yaratish'],
  '3003': ['Фармацевтическая наука', 'Farmatsevtika fani'],
  '3004': ['Фармакология', 'Farmakologiya'],
  '3005': ['Токсикология', 'Toksikologiya'],
  '3102': ['Акустика и ультразвук', 'Akustika va ultratovush'],
  '3103': ['Астрономия и астрофизика', 'Astronomiya va astrofizika'],
  '3104': [
    'Физика конденсированного состояния',
    'Kondensirlangan holat fizikasi'
  ],
  '3105': [
    'Приборостроение и измерительная техника',
    'Asbobsozlik va o‘lchov texnikasi'
  ],
  '3106': [
    'Ядерная физика и физика высоких энергий',
    'Yadro fizikasi va yuqori energiyalar fizikasi'
  ],
  '3107': [
    'Атомная и молекулярная физика, оптика',
    'Atom va molekulyar fizika, optika'
  ],
  '3108': ['Излучение', 'Nurlanish'],
  '3109': [
    'Статистическая и нелинейная физика',
    'Statistik va nochiziqli fizika'
  ],
  '3200': ['Психология (общее)', 'Psixologiya (umumiy)'],
  '3202': ['Прикладная психология', 'Amaliy psixologiya'],
  '3203': ['Клиническая психология', 'Klinik psixologiya'],
  '3204': [
    'Психология развития и педагогическая психология',
    'Rivojlanish psixologiyasi va pedagogik psixologiya'
  ],
  '3205': [
    'Экспериментальная и когнитивная психология',
    'Eksperimental va kognitiv psixologiya'
  ],
  '3206': [
    'Нейропсихология и психофизиология',
    'Neyropsixologiya va psixofiziologiya'
  ],
  '3207': ['Социальная психология', 'Ijtimoiy psixologiya'],
  '3300': ['Социальные науки (общее)', 'Ijtimoiy fanlar (umumiy)'],
  '3302': ['Археология (социальные науки)', 'Arxeologiya (ijtimoiy fanlar)'],
  '3303': [
    'Развитие (социально-экономическое)',
    'Rivojlanish (ijtimoiy-iqtisodiy)'
  ],
  '3304': ['Образование и педагогика', 'Ta‘lim va pedagogika'],
  '3305': [
    'География, планирование и развитие территорий',
    'Geografiya, rejalashtirish va hududlar rivoji'
  ],
  '3306': ['Здоровье (социальные аспекты)', 'Salomatlik (ijtimoiy jihatlar)'],
  '3307': ['Эргономика и человеческий фактор', 'Ergonomika va inson omili'],
  '3308': ['Право и юриспруденция', 'Huquq va yurisprudensiya'],
  '3309': [
    'Библиотековедение и информационные науки',
    'Kutubxonashunoslik va axborot fanlari'
  ],
  '3310': ['Лингвистика и язык', 'Lingvistika va til'],
  '3311': ['Исследования безопасности', 'Xavfsizlik tadqiqotlari'],
  '3312': ['Социология и политология', 'Sotsiologiya va siyosatshunoslik'],
  '3313': ['Транспорт', 'Transport'],
  '3314': ['Антропология', 'Antropologiya'],
  '3315': ['Коммуникация и журналистика', 'Kommunikatsiya va jurnalistika'],
  '3316': ['Культурология', 'Madaniyatshunoslik'],
  '3317': ['Демография', 'Demografiya'],
  '3318': ['Гендерные исследования', 'Gender tadqiqotlari'],
  '3319': ['Исследования жизненного пути', 'Hayot yo‘li tadqiqotlari'],
  '3320': [
    'Политология и международные отношения',
    'Siyosatshunoslik va xalqaro munosabatlar'
  ],
  '3321': ['Государственное управление', 'Davlat boshqaruvi'],
  '3322': ['Урбанистика', 'Urbanistika'],
  '3402': ['Ветеринария: лошади', 'Veterinariya: otlar'],
  '3404': ['Ветеринария: мелкие животные', 'Veterinariya: mayda hayvonlar'],
  '3500': ['Стоматология (общее)', 'Stomatologiya (umumiy)'],
  '3504': ['Хирургическая стоматология', 'Jarrohlik stomatologiyasi'],
  '3505': ['Ортодонтия', 'Ortodontiya'],
  '3506': ['Пародонтология', 'Parodontologiya'],
  '3600': [
    'Медицинские специальности (общее)',
    'Tibbiyot mutaxassisliklari (umumiy)'
  ],
  '3603': [
    'Мануальная и комплементарная терапия',
    'Manual va komplementar terapiya'
  ],
  '3604': ['Скорая медицинская помощь', 'Tez tibbiy yordam'],
  '3605': ['Управление медицинской информацией', 'Tibbiy axborotni boshqarish'],
  '3607': [
    'Медицинская лабораторная диагностика',
    'Tibbiy laboratoriya diagnostikasi'
  ],
  '3608': ['Медицинская терминология', 'Tibbiy terminologiya'],
  '3609': ['Эрготерапия', 'Ergoterapiya'],
  '3611': ['Фармация', 'Farmatsiya'],
  '3612': [
    'Физиотерапия, спортивная терапия и реабилитация',
    'Fizioterapiya, sport terapiyasi va reabilitatsiya'
  ],
  '3614': [
    'Лучевая и ультразвуковая диагностика',
    'Nur va ultratovush diagnostikasi'
  ],
  '3616': ['Логопедия и сурдология', 'Logopediya va surdologiya'],
};

/// Привычные названия специальностей (ВАК/ОАК и бытовые) → разделы OpenAlex.
const Map<String, List<String>> taxonomyAliases = {
  '3304': [
    'педагогика',
    'педагогические науки',
    'дидактика',
    'методика преподавания',
    'методика обучения',
    'образование',
    'обучение',
    'школа',
    'pedagogika',
    'pedagogik fanlar',
    'didaktika',
    'o‘qitish metodikasi',
    'ta‘lim',
    'maktab',
    'pedagogy',
    'teaching',
    'school'
  ],
  '3204': [
    'педагогическая психология',
    'детская психология',
    'pedagogik psixologiya',
    'bolalar psixologiyasi'
  ],
  '1203': ['филология', 'языкознание', 'filologiya', 'tilshunoslik'],
  '1208': ['филология', 'литература', 'filologiya', 'adabiyot'],
  '3310': ['филология', 'язык', 'лингвистика', 'filologiya', 'til'],
  '3308': [
    'юриспруденция',
    'юридические науки',
    'право',
    'huquqshunoslik',
    'yuridik fanlar',
    'huquq'
  ],
  '2002': [
    'экономика',
    'экономические науки',
    'iqtisodiyot',
    'iqtisodiyot fanlari'
  ],
  '1202': [
    'история',
    'исторические науки',
    'востоковедение',
    'tarix',
    'tarix fanlari',
    'sharqshunoslik'
  ],
  '3316': [
    'востоковедение',
    'культурология',
    'sharqshunoslik',
    'madaniyatshunoslik'
  ],
  '3200': [
    'психология',
    'психологические науки',
    'psixologiya',
    'psixologiya fanlari'
  ],
  '3320': [
    'политология',
    'политические науки',
    'siyosatshunoslik',
    'siyosiy fanlar'
  ],
  '3312': ['социология', 'социологические науки', 'sotsiologiya'],
  '1211': ['философия', 'философские науки', 'falsafa', 'falsafa fanlari'],
  '1213': ['искусствоведение', 'san’atshunoslik', 'санъатшунослик'],
  '3315': ['журналистика', 'jurnalistika'],
  '2732': [
    'физическая культура',
    'физкультура',
    'спорт',
    'jismoniy tarbiya',
    'sport'
  ],
  '3612': ['физическая культура', 'спорт', 'jismoniy tarbiya', 'sport'],
  '1102': [
    'сельское хозяйство',
    'агрономия',
    'qishloq xo‘jaligi',
    'agronomiya'
  ],
  '2724': ['медицина', 'лечебное дело', 'tibbiyot', 'davolash ishi'],
  '1702': [
    'ии',
    'нейросети',
    'машинное обучение',
    'sun’iy intellekt',
    'neyron tarmoqlar',
    'mashinali o‘qitish'
  ],
  '3305': ['география', 'geografiya'],
};
