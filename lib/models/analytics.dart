// Отчёты «Scinode Аналитика» (формат schema 1, см. analytics/README.md).
// Файлы считает GitHub раз в месяц и публикует на GitHub Pages.

int _i(Object? v) => v is num ? v.toInt() : 0;
double? _d(Object? v) => v is num ? v.toDouble() : null;
String _s(Object? v) => v == null ? '' : v.toString().trim();
List<Map<String, dynamic>> _maps(Object? v) => [
      if (v is List)
        for (final x in v)
          if (x is Map) Map<String, dynamic>.from(x),
    ];
List<String> _strs(Object? v) => [
      if (v is List)
        for (final x in v)
          if (_s(x).isNotEmpty) _s(x),
    ];

/// Схема, которую понимает приложение. Новая схема — новая папка v<N>.
const analyticsSchema = 1;

class OrgSummary {
  OrgSummary({
    required this.id,
    required this.name,
    this.acronyms = const [],
    this.alt = const [],
    this.type = '',
    this.ror = '',
    this.city = '',
    this.url = '',
    this.worksWindow = 0,
    this.worksTotal = 0,
    this.citationsTotal = 0,
    this.h = 0,
    this.i10 = 0,
  });

  final String id;
  final String name;
  final List<String> acronyms;
  final List<String> alt;
  final String type;
  final String ror;
  final String city;
  final String url;
  final int worksWindow;
  final int worksTotal;
  final int citationsTotal;
  final int h;
  final int i10;

  bool get isCountry => type == 'country';

  factory OrgSummary.fromJson(Map<String, dynamic> j) => OrgSummary(
        id: _s(j['id']),
        name: _s(j['name']).replaceAll(RegExp(r'\s+'), ' '),
        acronyms: _strs(j['acronyms']),
        alt: _strs(j['alt']),
        type: _s(j['type']),
        ror: _s(j['ror']),
        city: _s(j['city']),
        url: _s(j['url']),
        worksWindow: _i(j['works_window']),
        worksTotal: _i(j['works_total']),
        citationsTotal: _i(j['citations_total']),
        h: _i(j['h']),
        i10: _i(j['i10']),
      );

  /// Название на языке интерфейса, если OpenAlex знает такой вариант:
  /// ru — первое название кириллицей, uz — узбекское латиницей.
  String localName(String lang) {
    if (lang == 'ru') {
      // Русское — кириллица без букв узбекской, украинской и таджикской
      // кириллицы (ў қ ғ ҳ і ї є ґ ӯ ҷ): иначе «Бухоро давлат тиббиёт
      // институти» выдавалось бы за русское название.
      for (final a in alt) {
        if (RegExp(r'[А-Яа-яЁё]').hasMatch(a) &&
            !RegExp(r'[ЎўҚқҒғҲҳІіЇїЄєҐґӮӯҶҷ]').hasMatch(a) &&
            !_uzCyrillicWords.hasMatch(a.toLowerCase())) {
          return a;
        }
      }
    } else if (lang == 'uz') {
      for (final a in alt) {
        if (_looksUzbek(a)) return a;
      }
    }
    return name;
  }

  /// Слова узбекской кириллицы, которые пишутся русскими буквами.
  static final _uzCyrillicWords = RegExp(
      r'(номидаги|давлат|университети|институти|академияси|илмий|маркази)');

  static bool _looksUzbek(String s) {
    if (RegExp(r'[А-Яа-яЁё]').hasMatch(s)) return false;
    final l = s.toLowerCase();
    return RegExp(r"[ʻʼ‘’'`]").hasMatch(s) &&
            RegExp(r"(o|g)[ʻʼ‘’'`]").hasMatch(l) ||
        RegExp(r'\b(universiteti|instituti|akademiyasi|nomidagi|davlat)\b')
            .hasMatch(l);
  }

  /// Подходит ли под поиск: название, сокращения, другие названия, город.
  bool matches(String query) {
    final q = _fold(query);
    if (q.isEmpty) return true;
    final all = [name, ...acronyms, ...alt, city].map(_fold);
    final words = q.split(' ').where((w) => w.isNotEmpty);
    return words.every((w) => all.any((s) => s.contains(w)));
  }
}

/// Для поиска: нижний регистр, апострофы узбекской латиницы и ё не мешают.
String _fold(String s) => s
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r"[ʻʼ‘’'`]"), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class AnalyticsIndex {
  AnalyticsIndex({
    required this.schema,
    required this.generated,
    required this.windowFrom,
    required this.windowTo,
    required this.yearsFrom,
    required this.yearsTo,
    required this.country,
    required this.national,
    required this.orgs,
    this.minWorks = 100,
    this.minTopicWorks = 30,
  });

  final int schema;
  final DateTime? generated;
  final int windowFrom;
  final int windowTo;
  final int yearsFrom;
  final int yearsTo;
  final String country;
  final bool national;
  final List<OrgSummary> orgs;
  final int minWorks;
  final int minTopicWorks;

  factory AnalyticsIndex.fromJson(Map<String, dynamic> j) {
    final w = j['window'] is List ? j['window'] as List : const [];
    final y = j['years'] is List ? j['years'] as List : const [];
    return AnalyticsIndex(
      schema: _i(j['schema']),
      generated: DateTime.tryParse(_s(j['generated'])),
      windowFrom: w.isNotEmpty ? _i(w[0]) : 0,
      windowTo: w.length > 1 ? _i(w[1]) : 0,
      yearsFrom: y.isNotEmpty ? _i(y[0]) : 0,
      yearsTo: y.length > 1 ? _i(y[1]) : 0,
      country: _s(j['country']),
      national: j['national'] == true,
      orgs: [for (final o in _maps(j['orgs'])) OrgSummary.fromJson(o)]
        ..removeWhere((o) => o.id.isEmpty),
      minWorks: _i(j['min_works']),
      minTopicWorks: _i(j['min_topic_works']),
    );
  }
}

class YearRow {
  YearRow(
      this.year, this.all, this.article, this.conference, this.other, this.oa);
  final int year;
  final int all;
  final int article;
  final int conference;
  final int other;
  final int oa;

  double? get oaShare => all > 0 ? oa / all : null;
}

/// Название и число (тип работы, страна, вид доступа…).
class Named {
  Named(this.id, this.name, this.n);
  final String id;
  final String name;
  final int n;

  static List<Named> list(Object? v) => [
        for (final x in _maps(v))
          if (_s(x['id']).isNotEmpty)
            Named(_s(x['id']), _s(x['name']), _i(x['n'])),
      ];
}

class Citation {
  Citation({
    required this.known,
    required this.top10,
    required this.top1,
    required this.ppTop10,
    required this.ppTop1,
    required this.fwciKnown,
    required this.cited,
    required this.above1,
    required this.citedShare,
    required this.above1Share,
    this.lead,
    this.megaWorks = 0,
    this.megaTop10 = 0,
    this.ppTop10WithoutMega,
  });
  final int known;
  final int top10;
  final int top1;
  final double? ppTop10;
  final double? ppTop1;
  final int fwciKnown;
  final int cited;
  final int above1;
  final double? citedShare;
  final double? above1Share;

  /// Ведущие работы (автор для переписки — из организации); у страны нет.
  final LeadWorks? lead;

  /// Работы с больше чем 100 авторами (CERN и т. п.) и сколько из них в топ-10 %.
  final int megaWorks;
  final int megaTop10;
  final double? ppTop10WithoutMega;

  factory Citation.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    final f = m(j['fwci']);
    final l = j['lead'] is Map ? m(j['lead']) : null;
    final mg = m(j['mega']);
    return Citation(
      lead: l == null
          ? null
          : LeadWorks(
              works: _i(l['works']),
              share: _d(l['share']),
              known: _i(l['known']),
              top10: _i(l['top10']),
              top1: _i(l['top1']),
              ppTop10: _d(l['pp_top10']),
              ppTop1: _d(l['pp_top1']),
            ),
      megaWorks: _i(mg['works']),
      megaTop10: _i(mg['top10']),
      ppTop10WithoutMega: _d(mg['pp_top10_without']),
      known: _i(j['known']),
      top10: _i(j['top10']),
      top1: _i(j['top1']),
      ppTop10: _d(j['pp_top10']),
      ppTop1: _d(j['pp_top1']),
      fwciKnown: _i(f['known']),
      cited: _i(f['cited']),
      above1: _i(f['above1']),
      citedShare: _d(f['cited_share']),
      above1Share: _d(f['above1_share']),
    );
  }
}

class LeadWorks {
  LeadWorks({
    required this.works,
    required this.share,
    required this.known,
    required this.top10,
    required this.top1,
    required this.ppTop10,
    required this.ppTop1,
  });
  final int works;

  /// Доля ведущих среди всех работ организации.
  final double? share;
  final int known;
  final int top10;
  final int top1;
  final double? ppTop10;
  final double? ppTop1;
}

class Partner {
  Partner(this.id, this.name, this.country, this.type, this.n);
  final String id;
  final String name;
  final String country;
  final String type;
  final int n;
}

class TopAuthor {
  TopAuthor({
    required this.id,
    required this.name,
    required this.orcid,
    required this.n,
    required this.works,
    required this.citations,
    required this.h,
    required this.inst,
  });
  final String id;
  final String name;
  final String orcid;
  final int n;
  final int works;
  final int citations;
  final int h;
  final String inst;

  String get openAlexUrl => 'https://openalex.org/$id';
}

class Journal {
  Journal({
    required this.id,
    required this.name,
    required this.type,
    required this.issn,
    required this.doaj,
    required this.oa,
    required this.publisher,
    required this.country,
    required this.h,
    required this.mean2y,
    required this.n,
  });
  final String id;
  final String name;
  final String type; // journal, repository, conference, ebook platform…
  final String issn;
  final bool doaj;
  final bool oa;
  final String publisher;
  final String country;
  final int h;
  final double mean2y;
  final int n;
}

class TopicRow {
  TopicRow({
    required this.id,
    required this.name,
    required this.n,
    required this.top10,
    required this.known,
    required this.ppTop10,
    required this.strong,
    this.lead,
    this.leadShare,
    this.leadKnown = 0,
    this.leadTop10 = 0,
    this.leadPpTop10,
  });
  final String id; // номер раздела OpenAlex (subfield), например 3304
  final String name; // английское название
  final int n;
  final int top10;
  final int known;
  final double? ppTop10;

  /// «Сильное» по правилу расчёта (по ведущим работам, с запасом точности).
  final bool strong;

  /// Ведущих работ в разделе (null — у страны и в старых файлах).
  final int? lead;
  final double? leadShare;
  final int leadKnown;
  final int leadTop10;
  final double? leadPpTop10;

  /// Большинство работ — чужие статьи, где организация лишь соавтор.
  bool get mostlyGuest => leadShare != null && leadShare! < 0.3 && n >= 20;
}

/// Отозванные статьи и типы источников (журнал, репозиторий, конференция).
class Integrity {
  Integrity({this.retracted, this.sourceTypes = const []});

  /// null — в файле нет сведений (старый расчёт).
  final int? retracted;
  final List<Named> sourceTypes;

  int get repository =>
      sourceTypes.where((s) => s.id == 'repository').fold(0, (a, b) => a + b.n);
}

class OrgReport {
  OrgReport({
    required this.org,
    required this.generated,
    required this.windowFrom,
    required this.windowTo,
    required this.works,
    required this.years,
    required this.types,
    required this.oaWindow,
    required this.oaStatus,
    required this.citation,
    required this.intl,
    required this.intlShare,
    required this.countries,
    required this.partners,
    required this.authors,
    required this.doaj,
    required this.doajKnown,
    required this.doajShare,
    required this.journals,
    required this.topics,
    required this.integrity,
  });

  final OrgSummary org;
  final DateTime? generated;
  final int windowFrom;
  final int windowTo;

  /// Работ за окно (5 последних полных лет).
  final int works;
  final List<YearRow> years;
  final List<Named> types;
  final int oaWindow;
  final List<Named> oaStatus;
  final Citation citation;
  final int intl;
  final double? intlShare;
  final List<Named> countries;
  final List<Partner> partners;
  final List<TopAuthor> authors;
  final int doaj;
  final int doajKnown;
  final double? doajShare;
  final List<Journal> journals;
  final List<TopicRow> topics;
  final Integrity integrity;

  double? get oaShare => works > 0 ? oaWindow / works : null;

  List<TopicRow> get strongTopics => [
        for (final t in topics)
          if (t.strong) t,
      ];

  factory OrgReport.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    final w = j['window'] is List ? j['window'] as List : const [];
    final oa = m(j['oa']);
    final collab = m(j['collab']);
    final jr = m(j['journals']);
    final ig = m(j['integrity']);
    return OrgReport(
      integrity: Integrity(
        retracted: ig['retracted'] is num ? _i(ig['retracted']) : null,
        sourceTypes: Named.list(ig['source_types']),
      ),
      org: OrgSummary.fromJson(m(j['org'])),
      generated: DateTime.tryParse(_s(j['generated'])),
      windowFrom: w.isNotEmpty ? _i(w[0]) : 0,
      windowTo: w.length > 1 ? _i(w[1]) : 0,
      works: _i(j['works']),
      years: [
        for (final y in _maps(j['years']))
          YearRow(_i(y['y']), _i(y['all']), _i(y['article']),
              _i(y['conference']), _i(y['other']), _i(y['oa'])),
      ]..sort((a, b) => a.year.compareTo(b.year)),
      types: Named.list(j['types']),
      oaWindow: _i(oa['n']),
      oaStatus: Named.list(oa['status']),
      citation: Citation.fromJson(m(j['citation'])),
      intl: _i(collab['intl']),
      intlShare: _d(collab['intl_share']),
      countries: Named.list(collab['countries']),
      partners: [
        for (final p in _maps(collab['partners']))
          Partner(_s(p['id']), _s(p['name']), _s(p['country']), _s(p['type']),
              _i(p['n'])),
      ],
      authors: [
        for (final a in _maps(j['authors']))
          TopAuthor(
            id: _s(a['id']),
            name: _s(a['name']),
            orcid: _s(a['orcid']),
            n: _i(a['n']),
            works: _i(a['works']),
            citations: _i(a['citations']),
            h: _i(a['h']),
            inst: _s(a['inst']),
          ),
      ],
      doaj: _i(jr['doaj']),
      doajKnown: _i(jr['known']),
      doajShare: _d(jr['doaj_share']),
      journals: [
        for (final s in _maps(jr['top']))
          Journal(
            id: _s(s['id']),
            name: _s(s['name']),
            type: _s(s['type']),
            issn: _s(s['issn']),
            doaj: s['doaj'] == true,
            oa: s['oa'] == true,
            publisher: _s(s['publisher']),
            country: _s(s['country']),
            h: _i(s['h']),
            mean2y: _d(s['mean2y']) ?? 0,
            n: _i(s['n']),
          ),
      ],
      topics: [
        for (final t in _maps(j['topics']))
          TopicRow(
            id: _s(t['id']),
            name: _s(t['name']),
            n: _i(t['n']),
            top10: _i(t['top10']),
            known: _i(t['known']),
            ppTop10: _d(t['pp_top10']),
            strong: t['strong'] == true,
            lead: t['lead'] is num ? _i(t['lead']) : null,
            leadShare: _d(t['lead_share']),
            leadKnown: _i(t['lead_known']),
            leadTop10: _i(t['lead_top10']),
            leadPpTop10: _d(t['lead_pp_top10']),
          ),
      ],
    );
  }
}

/// Доля в процентах для подписи: 0.0594 → «5,9 %» (ru/uz) или «5.9%» (en).
String formatShare(double? v, String lang) {
  if (v == null) return '—';
  final p = v * 100;
  final s = p >= 10 || p == 0 ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
  // Неразрывный пробел: «5,9 %» не переносится на две строки.
  return lang == 'en' ? '$s%' : '${s.replaceAll('.', ',')}\u00a0%';
}
