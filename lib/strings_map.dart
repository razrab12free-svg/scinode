// Тексты карты науки. Порядок: русский, узбекский, английский.
const Map<String, List<String>> mapStrings = {
  'map.title': ['Карта науки', 'Fan xaritasi', 'Science map'],
  'map.tile_sub': [
    'Университеты и научные центры мира, их связи',
    'Dunyo universitetlari va ilmiy markazlari, ularning aloqalari',
    'Universities and research centres worldwide and their links',
  ],
  'map.country': ['Страна', 'Davlat', 'Country'],
  'map.type': ['Тип', 'Turi', 'Type'],
  'map.type.any': ['Любой тип', 'Istalgan tur', 'Any type'],
  'map.field': ['Направление', 'Yo‘nalish', 'Field'],
  'map.color': ['Цвет', 'Rang', 'Colour'],
  'map.color.type': ['Цвет: тип', 'Rang: turi', 'Colour: type'],
  'map.color.cited': [
    'Цвет: цитируемость',
    'Rang: iqtiboslanish',
    'Colour: citations',
  ],
  'map.loading': [
    'Загружаем организации…',
    'Tashkilotlar yuklanmoqda…',
    'Loading institutions…',
  ],
  'map.count': [
    'Организаций на карте: {n}',
    'Xaritada tashkilotlar: {n}',
    'Institutions on map: {n}',
  ],
  'map.empty': [
    'По этим фильтрам организаций не найдено',
    'Bu filtrlar bo‘yicha tashkilot topilmadi',
    'No institutions match these filters',
  ],
  'map.legend.size': [
    'Размер — число работ',
    'Hajmi — ishlar soni',
    'Size — number of works',
  ],
  'map.legend.size_field': [
    'Размер — работы по направлению за 5 лет',
    'Hajmi — 5 yildagi yo‘nalish bo‘yicha ishlar',
    'Size — works in the field over 5 years',
  ],
  'map.legend.cited': [
    'Цитирований на работу',
    'Bitta ishga iqtiboslar',
    'Citations per work',
  ],
  'map.legend.hide': ['Скрыть легенду', 'Izohni yashirish', 'Hide legend'],
  'map.legend.show': ['Легенда', 'Izoh', 'Legend'],
  'type.education': ['Университет', 'Universitet', 'University'],
  'type.healthcare': ['Медицина', 'Tibbiyot', 'Healthcare'],
  'type.company': ['Компания', 'Kompaniya', 'Company'],
  'type.government': ['Государственная', 'Davlat tashkiloti', 'Government'],
  'type.facility': [
    'Научный центр',
    'Ilmiy markaz',
    'Research facility',
  ],
  'type.nonprofit': ['Некоммерческая', 'Notijorat', 'Nonprofit'],
  'type.archive': ['Архив, музей', 'Arxiv, muzey', 'Archive'],
  'type.funder': ['Фонд', 'Jamg‘arma', 'Funder'],
  'type.other': ['Другое', 'Boshqa', 'Other'],
  'map.works': ['Работ: {n}', 'Ishlar: {n}', 'Works: {n}'],
  'map.cited': ['Цитирований: {n}', 'Iqtiboslar: {n}', 'Citations: {n}'],
  'map.h': ['h-индекс: {n}', 'h-indeks: {n}', 'h-index: {n}'],
  'map.activity': [
    'По направлению за 5 лет: {n}',
    '5 yilda yo‘nalish bo‘yicha: {n}',
    'In the field, 5 years: {n}',
  ],
  'map.topics': ['Ведущие темы', 'Yetakchi mavzular', 'Main topics'],
  'map.authors': [
    'Ведущие авторы за 5 лет',
    'So‘nggi 5 yil yetakchi mualliflari',
    'Top authors, last 5 years',
  ],
  'map.authors_works': ['{n} работ', '{n} ta ish', '{n} works'],
  'map.partners_show': [
    'Показать партнёров',
    'Hamkorlarni ko‘rsatish',
    'Show partners',
  ],
  'map.partners_title': [
    'Партнёры: {name}',
    'Hamkorlar: {name}',
    'Partners: {name}',
  ],
  'map.partners_sub': [
    'Совместные работы за 5 лет. Толщина линии — число работ.',
    '5 yillik qo‘shma ishlar. Chiziq qalinligi — ishlar soni.',
    'Joint works over 5 years. Line width — number of works.',
  ],
  'map.partners_list': [
    'Список партнёров',
    'Hamkorlar ro‘yxati',
    'Partner list'
  ],
  'map.partners_close': [
    'Скрыть партнёров',
    'Hamkorlarni yashirish',
    'Hide partners'
  ],
  'map.partners_empty': [
    'Совместных работ за 5 лет не найдено',
    '5 yilda qo‘shma ishlar topilmadi',
    'No joint works found in the last 5 years',
  ],
  'map.joint': ['{n} совм. работ', '{n} ta qo‘shma ish', '{n} joint works'],
  'map.open_oa': [
    'Профиль в OpenAlex',
    'OpenAlex’dagi profil',
    'OpenAlex profile',
  ],
  'map.site': ['Сайт организации', 'Tashkilot sayti', 'Website'],
  'map.err': [
    'Не удалось загрузить данные. Проверьте интернет и повторите.',
    'Ma’lumotlarni yuklab bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.',
    'Could not load data. Check your connection and try again.',
  ],
  'map.osm': [
    '© Участники OpenStreetMap',
    '© OpenStreetMap ishtirokchilari',
    '© OpenStreetMap contributors',
  ],
  'map.data': ['Данные: OpenAlex', 'Ma’lumotlar: OpenAlex', 'Data: OpenAlex'],
  'map.zoom_hint': [
    'Приблизьте карту — покажем организации этого региона',
    'Xaritani yaqinlashtiring — shu mintaqa tashkilotlarini ko‘rsatamiz',
    'Zoom in to see institutions of that region',
  ],
};
