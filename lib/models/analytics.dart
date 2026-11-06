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
    this.rorNames = const {},
    this.established,
  });

  final String id;
  final String name;

  /// Официальные названия из реестра ROR по языкам (ru, uz, en…).
  final Map<String, String> rorNames;

  /// Год основания (ROR).
  final int? established;
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
        rorNames: _rorNames(j['ror_data']),
        established: j['ror_data'] is Map && j['ror_data']['established'] is num
            ? (j['ror_data']['established'] as num).toInt()
            : null,
      );

  static Map<String, String> _rorNames(Object? r) {
    final n = r is Map ? r['names'] : null;
    if (n is! Map) return const {};
    return {
      for (final e in n.entries)
        if (_s(e.value).isNotEmpty) e.key.toString(): _s(e.value),
    };
  }

  /// Название на языке интерфейса, если OpenAlex знает такой вариант:
  /// ru — первое название кириллицей, uz — узбекское латиницей.
  String localName(String lang) {
    // Официальное название из ROR — надёжнее догадок по другим названиям.
    final official = rorNames[lang];
    if (official != null && official.isNotEmpty) return official;
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
    final all =
        [name, ...acronyms, ...alt, ...rorNames.values, city].map(_fold);
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
    this.crossref,
    this.crossrefPublisher = '',
    this.growthRatio,
    this.growthSharp = false,
    this.growthWorks = 0,
    this.growthBefore = 0,
    this.growthYear,
  });
  final String id;
  final String name;
  final String type; // journal, repository, conference, ebook platform…

  /// Есть ли журнал в Crossref (null — не проверялось: не журнал или нет ISSN).
  final bool? crossref;
  final String crossrefPublisher;

  /// Во сколько раз выросло число работ журнала за 3 года и резко ли.
  final double? growthRatio;
  final bool growthSharp;
  final int growthWorks;
  final int growthBefore;
  final int? growthYear;

  /// Повод проверить журнал: нет DOI в Crossref или резкий рост объёма.
  /// Только для журналов — у репозиториев (Zenodo и т. п.) рост нормален.
  bool get warning => type == 'journal' && (growthSharp || crossref == false);
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

/// Проверка самых цитируемых работ: самоцитирование (OpenCitations) и
/// откуда приходят цитирования (OpenAlex).
class CheckedWork {
  CheckedWork({
    required this.id,
    required this.doi,
    required this.title,
    required this.year,
    required this.source,
    required this.cited,
    required this.citing,
    required this.ownShare,
    required this.topName,
    required this.topShare,
    required this.ocN,
    required this.authorSc,
    required this.journalSc,
    required this.flags,
  });
  final String id;
  final String doi;
  final String title;
  final int? year;
  final String source;
  final int cited;
  final int citing;
  final double? ownShare;
  final String topName;
  final double? topShare;
  final int ocN;
  final int authorSc;
  final int journalSc;

  /// own_institution, one_institution, author_self, journal_self.
  final List<String> flags;

  double? get authorScShare => ocN > 0 ? authorSc / ocN : null;
  double? get journalScShare => ocN > 0 ? journalSc / ocN : null;
}

class CitationCheck {
  CitationCheck({
    required this.checked,
    required this.flagged,
    required this.ownShare,
    required this.authorScShare,
    required this.journalScShare,
    required this.ocCitations,
    required this.works,
  });
  final int checked;
  final int flagged;
  final double? ownShare;
  final double? authorScShare;
  final double? journalScShare;
  final int ocCitations;
  final List<CheckedWork> works;

  static CitationCheck? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return CitationCheck(
      checked: _i(j['checked']),
      flagged: _i(j['flagged']),
      ownShare: _d(j['own_share']),
      authorScShare: _d(j['author_sc_share']),
      journalScShare: _d(j['journal_sc_share']),
      ocCitations: _i(j['oc_citations']),
      works: [
        for (final w in _maps(j['works']))
          CheckedWork(
            id: _s(w['id']),
            doi: _s(w['doi']),
            title: _s(w['title']),
            year: w['year'] is num ? (w['year'] as num).toInt() : null,
            source: _s(w['source']),
            cited: _i(w['cited']),
            citing: _i(w['citing']),
            ownShare: _d(w['own_share']),
            topName: w['top_inst'] is Map ? _s(w['top_inst']['name']) : '',
            topShare: _d(w['top_share']),
            ocN: w['oc'] is Map ? _i(w['oc']['n']) : 0,
            authorSc: w['oc'] is Map ? _i(w['oc']['author_sc']) : 0,
            journalSc: w['oc'] is Map ? _i(w['oc']['journal_sc']) : 0,
            flags: _strs(w['flags']),
          ),
      ],
    );
  }
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

/// Вклад в цели устойчивого развития ООН (классификатор OpenAlex).
class SdgBlock {
  SdgBlock(this.works, this.share, this.goals);

  /// Работ хотя бы с одной целью.
  final int works;
  final double? share;

  /// Цели 1–17: (номер, число работ) по убыванию.
  final List<(int, int)> goals;

  static SdgBlock? fromJson(Object? v) {
    if (v is! Map) return null;
    return SdgBlock(
      _i(v['works']),
      _d(v['share']),
      [
        for (final g in _maps(v['goals']))
          if (_i(g['id']) >= 1 && _i(g['id']) <= 17) (_i(g['id']), _i(g['n'])),
      ],
    );
  }
}

/// Фонд, указанный в работах.
class FunderRow {
  FunderRow(this.id, this.name, this.country, this.n);
  final String id;
  final String name;
  final String country;
  final int n;

  String get openAlexUrl => 'https://openalex.org/$id';
}

class Funding {
  Funding(this.works, this.share, this.top);

  /// Работ, где указан хотя бы один фонд.
  final int works;
  final double? share;
  final List<FunderRow> top;

  static Funding? fromJson(Object? v) {
    if (v is! Map) return null;
    return Funding(_i(v['works']), _d(v['share']), [
      for (final f in _maps(v['top']))
        if (_s(f['id']).isNotEmpty)
          FunderRow(_s(f['id']), _s(f['name']), _s(f['country']), _i(f['n'])),
    ]);
  }
}

/// Оценка расходов на публикацию в открытом доступе (APC) по прайс-листам.
class ApcEstimate {
  ApcEstimate(this.works, this.usd, [this.lead]);
  final int works;
  final int usd;

  /// Только ведущие работы (автор для переписки — из организации).
  final ApcEstimate? lead;

  static ApcEstimate? fromJson(Object? v) {
    if (v is! Map) return null;
    return ApcEstimate(_i(v['works']), _i(v['usd']), fromJson(v['lead']));
  }
}

/// Автор с очень большим числом работ в год (порог Иоаннидиса).
class ProlificAuthor {
  ProlificAuthor({
    required this.id,
    required this.name,
    required this.inst,
    required this.n,
    required this.max,
    required this.maxYear,
    required this.yearsOver,
  });
  final String id;
  final String name;
  final String inst;

  /// Работ в этом наборе (организация/страна) за окно.
  final int n;

  /// Наибольшее число статей, обзоров и докладов за год (все места работы).
  final int max;
  final int maxYear;

  /// Сколько лет окна выше порога.
  final int yearsOver;

  String get openAlexUrl => 'https://openalex.org/$id';
}

class Prolific {
  Prolific(this.threshold, this.checked, this.authors);
  final int threshold;
  final int checked;
  final List<ProlificAuthor> authors;

  static Prolific? fromJson(Object? v) {
    if (v is! Map) return null;
    return Prolific(_i(v['threshold']), _i(v['checked']), [
      for (final a in _maps(v['authors']))
        if (_s(a['id']).isNotEmpty)
          ProlificAuthor(
            id: _s(a['id']),
            name: _s(a['name']),
            inst: _s(a['inst']),
            n: _i(a['n']),
            max: _i(a['max']),
            maxYear: _i(a['max_year']),
            yearsOver: _i(a['years_over']),
          ),
    ]);
  }
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
    this.citationCheck,
    this.sdg,
    this.languages = const [],
    this.funding,
    this.apc,
    this.prolific,
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

  /// Проверка цитирования самых цитируемых работ (только у организаций).
  final CitationCheck? citationCheck;

  // Разделы от ноября 2026; в старых файлах их нет (null / пусто).
  final SdgBlock? sdg;

  /// Языки публикаций (id — код ISO 639-1: en, uz, ru…).
  final List<Named> languages;
  final Funding? funding;
  final ApcEstimate? apc;
  final Prolific? prolific;

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
      citationCheck: CitationCheck.fromJson(j['citation_check']),
      sdg: SdgBlock.fromJson(j['sdg']),
      languages: Named.list(j['languages']),
      funding: Funding.fromJson(j['funding']),
      apc: ApcEstimate.fromJson(j['apc']),
      prolific: Prolific.fromJson(j['prolific']),
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
            crossref: s['crossref'] is bool ? s['crossref'] as bool : null,
            crossrefPublisher: _s(s['crossref_publisher']),
            growthRatio: s['growth'] is Map ? _d(s['growth']['ratio']) : null,
            growthSharp: s['growth'] is Map && s['growth']['sharp'] == true,
            growthWorks: s['growth'] is Map ? _i(s['growth']['works']) : 0,
            growthBefore:
                s['growth'] is Map ? _i(s['growth']['works_before']) : 0,
            growthYear: s['growth'] is Map && s['growth']['year'] is num
                ? (s['growth']['year'] as num).toInt()
                : null,
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

/// Доля работ на языке [code] (en, uz, ru) — null, если данных нет.
double? languageShare(OrgReport r, String code) {
  if (r.languages.isEmpty || r.works <= 0) return null;
  final n = r.languages.where((l) => l.id == code).fold(0, (a, b) => a + b.n);
  return n / r.works;
}

/// Доля в процентах для подписи: 0.0594 → «5,9 %» (ru/uz) или «5.9%» (en).
String formatShare(double? v, String lang) {
  if (v == null) return '—';
  final p = v * 100;
  final s = p >= 10 || p == 0 ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
  // Неразрывный пробел: «5,9 %» не переносится на две строки.
  return lang == 'en' ? '$s%' : '${s.replaceAll('.', ',')}\u00a0%';
}
