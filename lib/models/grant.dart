/// Модели и разбор ответов API грантов:
/// EU Funding & Tenders (SEDIA), Grants.gov, NIH RePORTER, NSF Awards.
library;

/// Источник данных о грантах.
enum GrantSource { eu, grantsGov, nih, nsf }

extension GrantSourceName on GrantSource {
  /// Короткое название источника (не переводится — это имена собственные).
  String get label => switch (this) {
        GrantSource.eu => 'EU Funding & Tenders',
        GrantSource.grantsGov => 'Grants.gov',
        GrantSource.nih => 'NIH RePORTER',
        GrantSource.nsf => 'NSF',
      };

  String get short => switch (this) {
        GrantSource.eu => 'EU',
        GrantSource.grantsGov => 'Grants.gov',
        GrantSource.nih => 'NIH',
        GrantSource.nsf => 'NSF',
      };
}

/// Статус конкурса.
enum CallStatus { open, forthcoming }

/// Открытый или скоро открывающийся конкурс.
class GrantCall {
  const GrantCall({
    required this.source,
    required this.id,
    required this.number,
    required this.title,
    required this.url,
    required this.status,
    this.agency = '',
    this.kind = '',
    this.openDate,
    this.deadline,
    this.deadlines = const [],
    this.budget,
    this.currency = '',
  });

  final GrantSource source;

  /// Внутренний идентификатор источника (для Grants.gov — opportunityId).
  final String id;

  /// Официальный номер конкурса (его удобно копировать).
  final String number;
  final String title;
  final String url;
  final CallStatus status;

  /// Ведомство или программа.
  final String agency;

  /// Тип: для EU — код типа (1, 2, 8), для Grants.gov — docType.
  final String kind;
  final DateTime? openDate;

  /// Ближайший будущий дедлайн.
  final DateTime? deadline;

  /// Все будущие дедлайны (для многоэтапных конкурсов EU).
  final List<DateTime> deadlines;
  final num? budget;
  final String currency;
}

/// Подробности конкурса Grants.gov (fetchOpportunity).
class GrantCallDetails {
  const GrantCallDetails({
    this.description = '',
    this.eligibility = '',
    this.applicantTypes = const [],
    this.instruments = const [],
    this.awardCeiling,
    this.awardFloor,
    this.totalFunding,
    this.awardsCount,
    this.costSharing,
    this.agencyName = '',
    this.contactEmail = '',
  });

  final String description;
  final String eligibility;
  final List<String> applicantTypes;
  final List<String> instruments;
  final num? awardCeiling;
  final num? awardFloor;
  final num? totalFunding;
  final int? awardsCount;
  final bool? costSharing;
  final String agencyName;
  final String contactEmail;
}

/// Профинансированный проект (NIH, NSF).
class FundedProject {
  const FundedProject({
    required this.source,
    required this.number,
    required this.title,
    required this.url,
    this.organization = '',
    this.place = '',
    this.investigators = const [],
    this.amount,
    this.currency = 'USD',
    this.start,
    this.end,
    this.abstractText = '',
    this.program = '',
  });

  final GrantSource source;
  final String number;
  final String title;
  final String url;
  final String organization;
  final String place;
  final List<String> investigators;
  final num? amount;
  final String currency;
  final DateTime? start;
  final DateTime? end;
  final String abstractText;
  final String program;
}

// ---------------------------------------------------------------------------
// Общие помощники
// ---------------------------------------------------------------------------

String? _s(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

num? _num(dynamic v) {
  if (v is num) return v;
  final s = _s(v);
  if (s == null) return null;
  return num.tryParse(s.replaceAll(',', ''));
}

/// Сжимает повторяющиеся пробелы (в NIH имена приходят как «Filiz  Yesilkoy»).
String squeeze(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Дата в формате США MM/dd/yyyy (Grants.gov, NSF).
DateTime? parseUsDate(dynamic v) {
  final s = _s(v);
  if (s == null) return null;
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (m == null) return null;
  final mo = int.parse(m.group(1)!);
  final d = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d);
}

/// Дата ISO 8601. Понимает и «+0000» без двоеточия (формат SEDIA).
DateTime? parseIsoDate(dynamic v) {
  var s = _s(v);
  if (s == null) return null;
  s = s.replaceFirstMapped(
      RegExp(r'([+-]\d{2})(\d{2})$'), (m) => '${m[1]}:${m[2]}');
  return DateTime.tryParse(s);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Сколько календарных дней осталось до [deadline] (по местному времени).
/// 0 — дедлайн сегодня, отрицательное число — уже прошёл.
int daysLeft(DateTime deadline, DateTime now) {
  final a = _day(deadline.toLocal());
  final b = _day(now.toLocal());
  return DateTime.utc(a.year, a.month, a.day)
      .difference(DateTime.utc(b.year, b.month, b.day))
      .inDays;
}

/// Срочность дедлайна: urgent — до 7 дней, soon — до 30 дней.
enum Urgency { urgent, soon, normal, none }

Urgency urgencyOf(DateTime? deadline, DateTime now) {
  if (deadline == null) return Urgency.none;
  final n = daysLeft(deadline, now);
  if (n <= 7) return Urgency.urgent;
  if (n <= 30) return Urgency.soon;
  return Urgency.normal;
}

/// Форма множественного числа: one / few / many.
/// Для русского — по правилам русского языка, для остальных — one / many.
String pluralForm(int n, String lang) {
  if (lang == 'ru') {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'one';
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'few';
    return 'many';
  }
  if (lang == 'en' && n == 1) return 'one';
  return 'many';
}

/// Дата для показа: 05.11.2026 (ru, uz) или 2026-11-05 (en).
String formatDate(DateTime d, String lang) {
  final l = d.toLocal();
  String two(int x) => x.toString().padLeft(2, '0');
  if (lang == 'en') return '${l.year}-${two(l.month)}-${two(l.day)}';
  return '${two(l.day)}.${two(l.month)}.${l.year}';
}

/// Сумма с разделителями разрядов: «$1,234,567» (en) или «1 234 567 $» (ru, uz).
String formatMoney(num amount, String currency, String lang) {
  final digits = amount.round().abs().toString();
  final sep = lang == 'en' ? ',' : ' ';
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(sep);
    b.write(digits[i]);
  }
  final sign = amount < 0 ? '-' : '';
  final sym = switch (currency) {
    'USD' => r'$',
    'EUR' => '€',
    _ => currency,
  };
  if (sym.isEmpty) return '$sign$b';
  if (lang == 'en') return '$sign$sym$b';
  return '$sign$b $sym';
}

/// Убирает HTML-теги и раскодирует основные HTML-сущности.
String stripHtml(String html) {
  var s = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|li|h\d)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const ents = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&rsquo;': '’',
    '&lsquo;': '‘',
    '&ldquo;': '“',
    '&rdquo;': '”',
    '&ndash;': '–',
    '&mdash;': '—',
  };
  ents.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final c = int.tryParse(m[1]!);
    return c == null ? m[0]! : String.fromCharCode(c);
  });
  s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
  s = s.replaceAll(RegExp(r' *\n *'), '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

/// Сортировка конкурсов: сначала по ближайшему дедлайну,
/// конкурсы без дедлайна — в конце (по дате открытия).
void sortCalls(List<GrantCall> list) {
  list.sort((a, b) {
    final da = a.deadline, db = b.deadline;
    if (da != null && db != null) return da.compareTo(db);
    if (da != null) return -1;
    if (db != null) return 1;
    final oa = a.openDate, ob = b.openDate;
    if (oa != null && ob != null) return oa.compareTo(ob);
    if (oa != null) return -1;
    if (ob != null) return 1;
    return a.title.compareTo(b.title);
  });
}

// ---------------------------------------------------------------------------
// EU Funding & Tenders (SEDIA search API)
// ---------------------------------------------------------------------------

/// Коды статусов SEDIA.
const euStatusForthcoming = '31094501';
const euStatusOpen = '31094502';

/// Типы SEDIA без закупок (0 — tenders):
/// 1 — темы конкурсов, 2 — конкурсы EuropeAid, 8 — каскадное финансирование.
const euGrantTypes = ['1', '2', '8'];

/// Метаданные SEDIA приходят списками: берём первое значение.
String? _first(dynamic m, String key) {
  if (m is! Map) return null;
  final v = m[key];
  if (v is List) return v.isEmpty ? null : _s(v.first);
  return _s(v);
}

List<String> _all(dynamic m, String key) {
  if (m is! Map) return const [];
  final v = m[key];
  if (v is List) return [for (final x in v) _s(x)].whereType<String>().toList();
  final one = _s(v);
  return one == null ? const [] : [one];
}

/// Официальная страница конкурса EU.
/// Ссылки вида .../data/topicDetails/ID.json заменяем на страницу портала.
String euPortalUrl(String url, String identifier) {
  if (url.contains('/data/topicDetails/') || url.isEmpty) {
    return 'https://ec.europa.eu/info/funding-tenders/opportunities/portal/'
        'screen/opportunities/topic-details/${Uri.encodeComponent(identifier)}';
  }
  return url;
}

/// Разбор одной страницы ответа SEDIA. Оставляет только конкурсы
/// с будущим дедлайном (у SEDIA бывают устаревшие «открытые» записи).
List<GrantCall> parseEuSearch(Map<String, dynamic> j, DateTime now) {
  final out = <GrantCall>[];
  final results = j['results'];
  if (results is! List) return out;
  for (final r in results) {
    if (r is! Map) continue;
    final m = r['metadata'];
    final type = _first(m, 'type') ?? '';
    if (!euGrantTypes.contains(type)) continue;
    final st = _first(m, 'status');
    final CallStatus status;
    if (st == euStatusOpen) {
      status = CallStatus.open;
    } else if (st == euStatusForthcoming) {
      status = CallStatus.forthcoming;
    } else {
      continue;
    }

    final deadlines = [
      for (final d in _all(m, 'deadlineDate')) parseIsoDate(d),
    ].whereType<DateTime>().where((d) => !d.isBefore(now)).toList()
      ..sort();
    if (deadlines.isEmpty) continue;

    final identifier = _first(m, 'identifier') ?? _s(r['reference']) ?? '';
    final topic = _first(m, 'title');
    final callTitle = _first(m, 'callTitle');
    // У каскадного финансирования (type 8) конкретный конкурс — в callTitle,
    // а в title — общая тема программы.
    final String title;
    final String agency;
    if (type == '8' && callTitle != null) {
      title = callTitle;
      agency = topic ?? '';
    } else {
      title = topic ?? callTitle ?? _s(r['summary']) ?? identifier;
      agency = _first(m, 'typesOfAction') ??
          (callTitle != null && callTitle != title ? callTitle : '');
    }
    final url = _s(r['url']) ?? _first(m, 'url') ?? '';

    out.add(GrantCall(
      source: GrantSource.eu,
      id: _s(r['reference']) ?? identifier,
      number: identifier,
      title: squeeze(title),
      url: euPortalUrl(url, identifier),
      status: status,
      agency: squeeze(agency),
      kind: type,
      openDate: parseIsoDate(_first(m, 'startDate')),
      deadline: deadlines.first,
      deadlines: deadlines,
      budget: _num(_first(m, 'budget')),
      currency: _first(m, 'currency') ?? 'EUR',
    ));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Grants.gov (search2, fetchOpportunity)
// ---------------------------------------------------------------------------

String grantsGovUrl(String id) =>
    'https://www.grants.gov/search-results-detail/$id';

/// Разбор ответа search2. Отбрасывает конкурсы с уже прошедшим дедлайном.
List<GrantCall> parseGrantsGovSearch(Map<String, dynamic> j, DateTime now) {
  final out = <GrantCall>[];
  final data = j['data'];
  final hits = data is Map ? data['oppHits'] : null;
  if (hits is! List) return out;
  for (final h in hits) {
    if (h is! Map) continue;
    final id = _s(h['id']);
    if (id == null) continue;
    final st = _s(h['oppStatus']);
    final CallStatus status;
    if (st == 'posted') {
      status = CallStatus.open;
    } else if (st == 'forecasted') {
      status = CallStatus.forthcoming;
    } else {
      continue;
    }
    final close = parseUsDate(h['closeDate']);
    if (close != null && daysLeft(close, now) < 0) continue;
    out.add(GrantCall(
      source: GrantSource.grantsGov,
      id: id,
      number: _s(h['number']) ?? id,
      title: squeeze(_s(h['title']) ?? '—'),
      url: grantsGovUrl(id),
      status: status,
      agency: _s(h['agency']) ?? _s(h['agencyCode']) ?? '',
      kind: _s(h['docType']) ?? '',
      openDate: parseUsDate(h['openDate']),
      deadline: close,
      deadlines: close == null ? const [] : [close],
      currency: 'USD',
    ));
  }
  return out;
}

List<String> _descList(dynamic v) {
  if (v is! List) return const [];
  return [
    for (final x in v)
      if (x is Map) _s(x['description']),
  ].whereType<String>().toList();
}

/// Разбор fetchOpportunity: данные берём из synopsis, а для прогнозов — из forecast.
GrantCallDetails parseGrantsGovDetails(Map<String, dynamic> j) {
  final data = j['data'];
  if (data is! Map) return const GrantCallDetails();
  final syn = data['synopsis'];
  final fc = data['forecast'];
  final Map s = syn is Map ? syn : (fc is Map ? fc : const {});
  final desc = _s(s['synopsisDesc']) ?? _s(s['forecastDesc']) ?? '';
  final cs = _s(s['costSharing']);
  final agency = data['agencyDetails'];
  return GrantCallDetails(
    description: stripHtml(desc),
    eligibility: stripHtml(_s(s['applicantEligibilityDesc']) ?? ''),
    applicantTypes: _descList(s['applicantTypes']),
    instruments: _descList(s['fundingInstruments']),
    awardCeiling: _positive(_num(s['awardCeiling'])),
    awardFloor: _positive(_num(s['awardFloor'])),
    totalFunding: _positive(_num(s['estimatedFunding'])),
    awardsCount: _positive(_num(s['numberOfAwards']))?.toInt(),
    costSharing: cs == null ? null : cs.toLowerCase() == 'true',
    agencyName: _s(s['agencyName']) ??
        (agency is Map ? _s(agency['agencyName']) : null) ??
        '',
    contactEmail: _s(s['agencyContactEmail']) ?? '',
  );
}

num? _positive(num? v) => v != null && v > 0 ? v : null;

// ---------------------------------------------------------------------------
// NIH RePORTER (v2/projects/search)
// ---------------------------------------------------------------------------

List<FundedProject> parseNih(Map<String, dynamic> j) {
  final out = <FundedProject>[];
  final results = j['results'];
  if (results is! List) return out;
  for (final r in results) {
    if (r is! Map) continue;
    final org = r['organization'];
    final pis = r['principal_investigators'];
    final names = <String>[];
    if (pis is List) {
      // Контактный руководитель — первым.
      final sorted = pis.whereType<Map>().toList()
        ..sort((a, b) => (b['is_contact_pi'] == true ? 1 : 0)
            .compareTo(a['is_contact_pi'] == true ? 1 : 0));
      for (final p in sorted) {
        final n = _s(p['full_name']) ??
            _s('${p['first_name'] ?? ''} ${p['last_name'] ?? ''}');
        if (n != null) names.add(squeeze(n));
      }
    }
    final place = org is Map
        ? [_s(org['org_city']), _s(org['org_state']), _s(org['org_country'])]
            .whereType<String>()
            .join(', ')
        : '';
    final appl = _s(r['appl_id']) ?? '';
    final ic = r['agency_ic_admin'];
    out.add(FundedProject(
      source: GrantSource.nih,
      number: _s(r['project_num']) ?? appl,
      title: squeeze(_s(r['project_title']) ?? '—'),
      url: _s(r['project_detail_url']) ??
          'https://reporter.nih.gov/project-details/$appl',
      organization: org is Map ? (_s(org['org_name']) ?? '') : '',
      place: place,
      investigators: names,
      amount: _num(r['award_amount']),
      start: parseIsoDate(r['project_start_date']),
      end: parseIsoDate(r['project_end_date']),
      abstractText: (_s(r['abstract_text']) ?? '').trim(),
      program:
          ic is Map ? (_s(ic['name']) ?? _s(ic['abbreviation']) ?? '') : '',
    ));
  }
  return out;
}

// ---------------------------------------------------------------------------
// NSF Award Search (services/v1/awards.json)
// ---------------------------------------------------------------------------

String nsfAwardUrl(String id) =>
    'https://www.nsf.gov/awardsearch/showAward?AWD_ID=$id';

/// Ключевые слова для NSF: слова через AND (иначе NSF ищет любое слово).
String nsfKeyword(String q) {
  final words = q
      .replaceAll('"', ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  return words.join(' AND ');
}

/// Из строки «Имя Фамилия email@x» оставляет только имя.
String _nameOnly(String s) =>
    squeeze(s.split(' ').where((w) => !w.contains('@')).join(' '));

List<FundedProject> parseNsf(Map<String, dynamic> j) {
  final out = <FundedProject>[];
  final resp = j['response'];
  final awards = resp is Map ? resp['award'] : null;
  if (awards is! List) return out;
  for (final a in awards) {
    if (a is! Map) continue;
    final id = _s(a['id']);
    if (id == null) continue;
    final names = <String>[];
    final pi = _s(a['pdPIName']);
    if (pi != null) names.add(squeeze(pi));
    final co = a['coPDPI'];
    if (co is List) {
      for (final c in co) {
        final n = _s(c);
        if (n != null) names.add(_nameOnly(n));
      }
    }
    final place = [_s(a['awardeeCity']), _s(a['awardeeStateCode'])]
        .whereType<String>()
        .join(', ');
    out.add(FundedProject(
      source: GrantSource.nsf,
      number: id,
      title: squeeze(_s(a['title']) ?? '—'),
      url: nsfAwardUrl(id),
      organization: _s(a['awardeeName']) ?? _s(a['awardee']) ?? '',
      place: place,
      investigators: names,
      amount: _num(a['fundsObligatedAmt']) ?? _num(a['estimatedTotalAmt']),
      start: parseUsDate(a['startDate']),
      end: parseUsDate(a['expDate']),
      abstractText: (_s(a['abstractText']) ?? '').trim(),
      program: _s(a['fundProgramName']) ?? '',
    ));
  }
  return out;
}

/// Сортировка проектов: сначала самые новые по дате начала.
void sortProjects(List<FundedProject> list) {
  list.sort((a, b) {
    final sa = a.start, sb = b.start;
    if (sa != null && sb != null) return sb.compareTo(sa);
    if (sa != null) return -1;
    if (sb != null) return 1;
    return a.title.compareTo(b.title);
  });
}
