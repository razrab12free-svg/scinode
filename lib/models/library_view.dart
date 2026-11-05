import 'paper.dart';

/// Фильтр библиотеки.
enum LibFilter { all, pdf, noPdf }

/// Сортировка библиотеки.
enum LibSort { recent, year, cited }

/// Отбирает и сортирует статьи библиотеки.
///
/// [items] — статьи в порядке добавления (новые первыми).
/// [query] ищется в названии, авторах и журнале; все слова должны найтись.
List<Paper> filterLibrary(
  List<Paper> items, {
  String query = '',
  LibFilter filter = LibFilter.all,
  LibSort sort = LibSort.recent,
  required bool Function(Paper) hasPdf,
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  bool matches(Paper p) {
    if (words.isEmpty) return true;
    final hay = '${p.title} ${p.authors.join(' ')} ${p.venue}'.toLowerCase();
    return words.every(hay.contains);
  }

  final out = <Paper>[
    for (final p in items)
      if (matches(p) &&
          switch (filter) {
            LibFilter.all => true,
            LibFilter.pdf => hasPdf(p),
            LibFilter.noPdf => !hasPdf(p),
          })
        p,
  ];

  // Сортировка устойчивая: при равенстве сохраняем порядок добавления.
  final index = {for (var i = 0; i < items.length; i++) items[i].id: i};
  int byAdded(Paper a, Paper b) =>
      (index[a.id] ?? 0).compareTo(index[b.id] ?? 0);

  switch (sort) {
    case LibSort.recent:
      break;
    case LibSort.year:
      out.sort((a, b) {
        final ya = a.year, yb = b.year;
        if (ya != yb) {
          if (ya == null) return 1;
          if (yb == null) return -1;
          return yb.compareTo(ya);
        }
        return byAdded(a, b);
      });
    case LibSort.cited:
      out.sort((a, b) {
        final c = b.citations.compareTo(a.citations);
        return c != 0 ? c : byAdded(a, b);
      });
  }
  return out;
}

/// Прогресс чтения PDF.
class ReadingPos {
  const ReadingPos({required this.page, required this.pages, this.at});

  /// Текущая страница (с 1).
  final int page;

  /// Всего страниц (0 — пока неизвестно).
  final int pages;
  final DateTime? at;

  /// Доля прочитанного 0..1.
  double get fraction =>
      pages <= 0 ? 0 : (page.clamp(1, pages) / pages).toDouble();

  Map<String, dynamic> toJson() => {
        'p': page,
        'n': pages,
        if (at != null) 'at': at!.millisecondsSinceEpoch,
      };

  static ReadingPos? fromJson(dynamic j) {
    if (j is! Map) return null;
    final p = j['p'], n = j['n'], at = j['at'];
    if (p is! int || p < 1) return null;
    return ReadingPos(
      page: p,
      pages: n is int && n > 0 ? n : 0,
      at: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null,
    );
  }
}
