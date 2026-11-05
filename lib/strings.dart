import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings_extra.dart';
import 'strings_grants.dart';
import 'strings_library.dart';
import 'strings_map.dart';
import 'strings_pdf.dart';
import 'strings_science.dart';

/// Язык приложения: uz (латиница), ru, en.
class Strings extends ChangeNotifier {
  Strings._();
  static final Strings instance = Strings._();

  static const names = {'uz': 'O‘zbekcha', 'ru': 'Русский', 'en': 'English'};
  static const _idx = {'ru': 0, 'uz': 1, 'en': 2};

  String lang = 'ru';
  bool loaded = false;

  Future<void> load() async {
    final code = PlatformDispatcher.instance.locale.languageCode;
    if (code == 'uz') {
      lang = 'uz';
    } else if (const {'ru', 'kk', 'ky', 'tg', 'be', 'uk'}.contains(code)) {
      lang = 'ru';
    } else {
      lang = 'en';
    }
    try {
      final p = await SharedPreferences.getInstance();
      lang = p.getString('lang') ?? lang;
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> setLang(String l) async {
    if (!_idx.containsKey(l) || l == lang) return;
    lang = l;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang', l);
    } catch (_) {}
  }

  String t(String key, [Map<String, Object>? args]) {
    final row = _db[key] ??
        extraStrings[key] ??
        pdfStrings[key] ??
        scienceStrings[key] ??
        grantStrings[key] ??
        libraryStrings[key] ??
        mapStrings[key];

    var s = row == null ? key : row[_idx[lang] ?? 0];
    if (args != null) {
      args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    }
    return s;
  }
}

String t(String key, [Map<String, Object>? args]) =>
    Strings.instance.t(key, args);

// Порядок: русский, узбекский, английский.
const Map<String, List<String>> _db = {
  'app.tagline': [
    'Открытая сеть учёных мира',
    'Dunyo olimlarining ochiq tarmog‘i',
    'The open network of scientists worldwide',
  ],
  'login.title': [
    'Находите коллег, гранты и знания',
    'Hamkasblar, grantlar va bilimlarni toping',
    'Find collaborators, grants and knowledge',
  ],
  'login.subtitle': [
    'Статьи, карта университетов и гранты — в одном приложении',
    'Maqolalar, universitetlar xaritasi va grantlar — bitta ilovada',
    'Papers, a map of universities and grants — in one app',
  ],
  'login.google': [
    'Войти через Google',
    'Google orqali kirish',
    'Sign in with Google',
  ],
  'login.note': [
    'Вход нужен только для создания вашего профиля. Мы ничего не публикуем без вашего согласия.',
    'Kirish faqat profilingizni yaratish uchun kerak. Roziligingizsiz hech narsa e’lon qilmaymiz.',
    'Sign-in is used only to create your profile. We never publish anything without your consent.',
  ],
  'login.not_configured': [
    'Firebase ещё не настроен (нужны данные проекта)',
    'Firebase hali sozlanmagan (loyiha maʼlumotlari kerak)',
    'Firebase is not configured yet (project details needed)',
  ],
  'login.failed': [
    'Не удалось войти',
    'Kirib bo‘lmadi',
    'Sign-in failed',
  ],
  'tab.home': ['Главная', 'Asosiy', 'Home'],
  'tab.search': ['Поиск', 'Qidiruv', 'Search'],
  'tab.library': ['Библиотека', 'Kutubxona', 'Library'],
  'tab.network': ['Сеть', 'Tarmoq', 'Network'],
  'tab.profile': ['Профиль', 'Profil', 'Profile'],
  'home.hello': ['Привет, {name}', 'Salom, {name}', 'Hello, {name}'],
  'home.friend': ['коллега', 'hamkasb', 'colleague'],
  'home.sub': [
    'Что хотите сделать сегодня?',
    'Bugun nima qilmoqchisiz?',
    'What would you like to do today?',
  ],
  'qa.papers': ['Найти статьи', 'Maqolalarni topish', 'Find papers'],
  'qa.scientists': ['Найти учёных', 'Olimlarni topish', 'Find scientists'],
  'qa.grants': ['Гранты', 'Grantlar', 'Grants'],
  'qa.map': ['Карта науки', 'Fan xaritasi', 'Science map'],
  'soon': ['Скоро', 'Tez orada', 'Coming soon'],
  'soon.in_dev': ['В разработке', 'Ishlab chiqilmoqda', 'In development'],
  'soon.search': [
    'Поиск статей по OpenAlex и другим открытым базам, фильтры по темам, ссылки на бесплатные PDF.',
    'OpenAlex va boshqa ochiq bazalar bo‘yicha maqolalar qidiruvi, mavzu filtrlari, bepul PDF havolalari.',
    'Search papers across OpenAlex and other open sources, topic filters, links to free PDFs.',
  ],
  'soon.library': [
    'Ваши статьи, PDF-читалка, заметки с формулами и синхронизация с Zotero.',
    'Maqolalaringiz, PDF o‘qish dasturi, formulali yozuvlar va Zotero bilan sinxronlash.',
    'Your papers, a PDF reader, notes with formulas and Zotero sync.',
  ],
  'soon.network': [
    'Умный поиск учёных, карта университетов и коллабораций, чат.',
    'Olimlarning aqlli qidiruvi, universitetlar va hamkorliklar xaritasi, chat.',
    'Smart scientist search, a map of universities and collaborations, chat.',
  ],
  'profile.guest': ['Учёный', 'Olim', 'Scientist'],
  'profile.language': ['Язык', 'Til', 'Language'],
  'profile.signout': ['Выйти', 'Chiqish', 'Sign out'],
  'profile.version': ['Версия {v}', 'Versiya {v}', 'Version {v}'],
  'profile.about': [
    'Данные о статьях и учёных предоставляют открытые источники, в том числе OpenAlex.',
    'Maqolalar va olimlar haqidagi maʼlumotlarni ochiq manbalar, jumladan OpenAlex taqdim etadi.',
    'Data about papers and scientists comes from open sources, including OpenAlex.',
  ],
};
