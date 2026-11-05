import 'package:flutter/material.dart';

import '../models/analytics.dart';
import '../models/grant.dart' show formatDate, formatMoney;
import '../models/taxonomy.dart';
import '../services/analytics_pdf.dart';
import '../services/analytics_service.dart';
import '../services/report_pdf.dart' show loadReportFonts;
import '../strings.dart';
import '../utils.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/grant_card.dart' show InfoNote;
import 'pdf_share_screen.dart';

String _num(int n) => formatMoney(n, '', Strings.instance.lang);
String _pct(double? v) => formatShare(v, Strings.instance.lang);
String _err(Object e) =>
    t('an.err.${e is AnalyticsException ? e.kind : 'other'}');
String _orgName(OrgSummary o) => o.isCountry || o.id == 'UZ'
    ? t('an.country_card')
    : o.localName(Strings.instance.lang);
String _typeLabel(String type) {
  final k = 'an.type.$type';
  final s = t(k);
  return s == k ? t('an.type.other') : s;
}

/// Перевод по ключу, если он есть, иначе запасной текст.
String _tr(String key, String fallback) {
  final s = t(key);
  return s == key ? fallback : s;
}

/// Открыть готовый PDF по организации (с кнопками «Сохранить» и «Поделиться»).
void openOrgPdf(BuildContext context, OrgReport r, OrgReport? country) {
  final lang = Strings.instance.lang;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PdfShareScreen(
      title: t('ap.pdf'),
      fileName: analyticsFileName(
          analyticsOrgName(r.org, 'en'), r.generated ?? DateTime.now()),
      build: () async => buildOrgPdf(r,
          country: country, fonts: await loadReportFonts(), lang: lang),
    ),
  ));
}

void openComparePdf(BuildContext context, OrgReport a, OrgReport b) {
  final lang = Strings.instance.lang;
  final name = [a.org, b.org]
      .map((o) => o.acronyms.isNotEmpty ? o.acronyms.first : o.id)
      .join('_');
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PdfShareScreen(
      title: t('ap.pdf'),
      fileName: analyticsFileName(
          '${t('ap.file_compare')}_$name', a.generated ?? DateTime.now()),
      build: () async =>
          buildComparePdf(a, b, fonts: await loadReportFonts(), lang: lang),
    ),
  ));
}

// ---------------------------------------------------------------------------
// Список организаций
// ---------------------------------------------------------------------------

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _q = TextEditingController();
  AnalyticsIndex? _idx;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final i = await AnalyticsService.instance.index(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _idx = i;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _open(String id) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => OrgReportScreen(id: id)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Strings.instance,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final idx = _idx;
        Widget body;
        if (_loading && idx == null) {
          body = const Center(child: CircularProgressIndicator());
        } else if (idx == null) {
          body = _ErrorView(text: _err(_error!), onRetry: () => _load());
        } else {
          final lang = Strings.instance.lang;
          final found = [
            for (final o in idx.orgs)
              if (o.matches(_q.text)) o,
          ];
          final bottom = MediaQuery.of(context).viewPadding.bottom;
          body = RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 24 + bottom),
              itemCount: found.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(t('an.intro'),
                            style: const TextStyle(fontSize: 14)),
                      ),
                      if (idx.generated != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            t('an.updated', {
                              'date': formatDate(idx.generated!, lang),
                              'from': idx.windowFrom,
                              'to': idx.windowTo,
                            }),
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: TextField(
                          key: const Key('an.search'),
                          controller: _q,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: t('an.search'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _q.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: MaterialLocalizations.of(context)
                                        .deleteButtonTooltip,
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() => _q.clear()),
                                  ),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (idx.national && _q.text.isEmpty)
                        Card(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          elevation: 0,
                          color: scheme.primaryContainer,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          child: ListTile(
                            key: const Key('an.country'),
                            minTileHeight: 64,
                            leading: Icon(Icons.flag_outlined,
                                color: scheme.onPrimaryContainer),
                            title: Text(t('an.country_card'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onPrimaryContainer)),
                            subtitle: Text(t('an.country_sub'),
                                style: TextStyle(
                                    color: scheme.onPrimaryContainer)),
                            trailing: Icon(Icons.chevron_right,
                                color: scheme.onPrimaryContainer),
                            onTap: () => _open(idx.country),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                        child: Text(
                          found.isEmpty
                              ? t('an.none')
                              : t('an.count', {'n': found.length}),
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  );
                }
                final o = found[i - 1];
                return _OrgTile(
                  org: o,
                  sub: [
                    _typeLabel(o.type),
                    if (o.city.isNotEmpty) o.city,
                    t('an.works_n', {
                      'from': idx.windowFrom,
                      'to': idx.windowTo,
                      'n': _num(o.worksWindow),
                    }),
                  ].join(' · '),
                  onTap: () => _open(o.id),
                );
              },
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(t('an.title'))),
          body: body,
        );
      },
    );
  }
}

class _OrgTile extends StatelessWidget {
  const _OrgTile({required this.org, required this.sub, required this.onTap});
  final OrgSummary org;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ac = org.acronyms.isNotEmpty ? ' (${org.acronyms.first})' : '';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        minTileHeight: 64,
        title: Text('${_orgName(org)}$ac',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(text,
                  key: const Key('an.error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(t('search.retry')),
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Отчёт по организации
// ---------------------------------------------------------------------------

/// Отчёт организации и (если есть) отчёт по стране для сравнения.
Future<(OrgReport, OrgReport?)> _loadWithCountry(String id) async {
  final svc = AnalyticsService.instance;
  final r = await svc.report(id);
  OrgReport? c;
  try {
    final idx = await svc.index();
    if (idx.national && id != idx.country) c = await svc.report(idx.country);
  } catch (_) {}
  return (r, c);
}

class OrgReportScreen extends StatefulWidget {
  const OrgReportScreen({super.key, required this.id});
  final String id;

  @override
  State<OrgReportScreen> createState() => _OrgReportScreenState();
}

class _OrgReportScreenState extends State<OrgReportScreen> {
  late Future<(OrgReport, OrgReport?)> _f = _loadWithCountry(widget.id);

  Future<void> _compare(OrgReport r) async {
    AnalyticsIndex idx;
    try {
      idx = await AnalyticsService.instance.index();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_err(e))));
      return;
    }
    if (!mounted) return;
    final other = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PickOrgSheet(index: idx, exclude: r.org.id),
    );
    if (other == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CompareScreen(a: r.org.id, b: other)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Strings.instance,
      builder: (context, _) => FutureBuilder<(OrgReport, OrgReport?)>(
        future: _f,
        builder: (context, snap) {
          final data = snap.data;
          return Scaffold(
            appBar: AppBar(
              title: Text(data == null ? t('an.title') : _orgName(data.$1.org),
                  maxLines: 2),
              actions: [
                if (data != null)
                  IconButton(
                    key: const Key('an.pdf_btn'),
                    tooltip: t('ap.pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () => openOrgPdf(context, data.$1, data.$2),
                  ),
                if (data != null)
                  IconButton(
                    key: const Key('an.compare_btn'),
                    tooltip: t('an.compare'),
                    icon: const Icon(Icons.compare_arrows),
                    onPressed: () => _compare(data.$1),
                  ),
              ],
            ),
            body: snap.hasError
                ? _ErrorView(
                    text: _err(snap.error!),
                    onRetry: () =>
                        setState(() => _f = _loadWithCountry(widget.id)),
                  )
                : data == null
                    ? const Center(child: CircularProgressIndicator())
                    : _ReportBody(
                        r: data.$1,
                        country: data.$2,
                        onCompare: () => _compare(data.$1),
                      ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.icon});
  final String title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: scheme.primary, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _BigNumber extends StatelessWidget {
  const _BigNumber(
      {super.key, required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: color ?? Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );
}

class _ReportBody extends StatelessWidget {
  const _ReportBody(
      {required this.r, required this.country, required this.onCompare});
  final OrgReport r;
  final OrgReport? country;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lang = Strings.instance.lang;
    final o = r.org;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final c = country;
    final win = {'from': r.windowFrom, 'to': r.windowTo};
    final isCountry = o.isCountry;

    return ListView(
      padding: EdgeInsets.only(top: 8, bottom: 24 + bottom),
      children: [
        // Шапка.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  _typeLabel(isCountry ? 'country' : o.type),
                  if (o.city.isNotEmpty) o.city,
                ].join(' · '),
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              if (!isCountry && _orgName(o) != o.name)
                Text(o.name, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Stat(_num(r.works), t('an.stat.works', win)),
                  if (!isCountry) _Stat('${o.h}', t('an.stat.h')),
                  if (!isCountry)
                    _Stat(_num(o.citationsTotal), t('an.stat.cites')),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('an.pdf_inline'),
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: () => openOrgPdf(context, r, country),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(t('ap.pdf')),
                  ),
                  if (o.url.isNotEmpty)
                    TextButton.icon(
                      style:
                          TextButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: () => openLink(context, o.url),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(t('an.open_site')),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: InfoNote(text: t('an.disclaimer')),
        ),

        // 1. Публикации по годам.
        _Section(
          title: t('an.s.years'),
          icon: Icons.bar_chart,
          children: [_YearsBlock(r: r)],
        ),

        // 2. Открытый доступ.
        _Section(
          title: t('an.s.oa'),
          icon: Icons.lock_open,
          children: [
            _BigNumber(value: _pct(r.oaShare), label: t('an.oa_share')),
            for (final s in r.oaStatus)
              CountBar(
                label: _tr('an.oa.${s.id}', s.name),
                value: s.n,
                max: r.works,
                valueText: _pct(r.works > 0 ? s.n / r.works : null),
                color: s.id == 'closed' ? scheme.outline : AnColors.good,
              ),
          ],
        ),

        // 3. Цитирование.
        _Section(
          title: t('an.s.cite'),
          icon: Icons.format_quote,
          children: [
            _Note(t('an.cite_note')),
            // Главное — собственные (ведущие) работы организации.
            if (r.citation.lead != null) ...[
              ShareBar(
                key: const Key('an.lead_top10'),
                label: t('an.c.lead_top10'),
                valueText: _pct(r.citation.lead!.ppTop10),
                value: r.citation.lead!.ppTop10,
                scaleMax: 0.2,
                world: 0.10,
                caption: t('an.world', {'v': _pct(0.10)}),
              ),
              _Note(t('an.lead_note', {
                'n': _num(r.citation.lead!.works),
                'all': _num(r.works),
                'p': _pct(r.citation.lead!.share),
              })),
            ],
            ShareBar(
              label: t('an.c.top10'),
              valueText: _pct(r.citation.ppTop10),
              value: r.citation.ppTop10,
              scaleMax: 0.2,
              world: 0.10,
              country: c?.citation.ppTop10,
              caption: [
                t('an.world', {'v': _pct(0.10)}),
                if (c != null)
                  t('an.country_v', {'v': _pct(c.citation.ppTop10)}),
              ].join(' · '),
            ),
            ShareBar(
              label: t('an.c.top1'),
              valueText: _pct(r.citation.ppTop1),
              value: r.citation.ppTop1,
              scaleMax: 0.02,
              world: 0.01,
              country: c?.citation.ppTop1,
              caption: [
                t('an.world', {'v': _pct(0.01)}),
                if (c != null)
                  t('an.country_v', {'v': _pct(c.citation.ppTop1)}),
              ].join(' · '),
            ),
            ShareBar(
              label: t('an.c.cited'),
              valueText: _pct(r.citation.citedShare),
              value: r.citation.citedShare,
              country: c?.citation.citedShare,
              caption: c == null
                  ? null
                  : t('an.country_v', {'v': _pct(c.citation.citedShare)}),
            ),
            ShareBar(
              label: t('an.c.above1'),
              valueText: _pct(r.citation.above1Share),
              value: r.citation.above1Share,
              scaleMax: 0.5,
              country: c?.citation.above1Share,
              caption: c == null
                  ? null
                  : t('an.country_v', {'v': _pct(c.citation.above1Share)}),
            ),
            if (r.citation.megaWorks > 0)
              _Note(t('an.mega_note', {
                'n': _num(r.citation.megaWorks),
                't': _num(r.citation.megaTop10),
                'p': _pct(r.citation.ppTop10WithoutMega),
              })),
          ],
        ),

        // 4. Направления.
        _Section(
          title: t('an.s.topics'),
          icon: Icons.insights,
          children: [
            _Note(t('an.topics_note', {'n': 30})),
            if (r.strongTopics.isEmpty) _Note(t('an.no_strong')),
            for (final tp in r.topics.take(12))
              CountBar(
                label: localSubfieldName(tp.id, tp.name),
                value: tp.n,
                max: r.topics.isEmpty ? 0 : r.topics.first.n,
                valueText: _num(tp.n),
                color: tp.strong ? AnColors.good : null,
                sub: tp.lead == null
                    ? t('an.topic_row', {'p': _pct(tp.ppTop10)})
                    : t('an.topic_row_lead', {
                        'n': _num(tp.lead!),
                        'p': _pct(tp.leadPpTop10),
                      }),
                trailing: tp.strong
                    ? _Chip(t('an.strong'), AnColors.good)
                    : tp.mostlyGuest
                        ? _Chip(t('an.guest'), AnColors.country)
                        : null,
              ),
          ],
        ),

        // 5. Партнёры.
        _Section(
          title: t('an.s.partners'),
          icon: Icons.handshake_outlined,
          children: [
            _BigNumber(value: _pct(r.intlShare), label: t('an.intl')),
            if (r.countries.isNotEmpty) ...[
              Text(t('an.countries'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final x in r.countries.take(10))
                CountBar(
                  label: countryName(x.id) == x.id ? x.name : countryName(x.id),
                  value: x.n,
                  max: r.countries.first.n,
                  valueText: _num(x.n),
                ),
              const SizedBox(height: 10),
            ],
            if (r.partners.isNotEmpty) ...[
              Text(t('an.partner_orgs'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final p in r.partners.take(10))
                CountBar(
                  label: p.name,
                  value: p.n,
                  max: r.partners.first.n,
                  valueText: _num(p.n),
                  sub: p.country.isEmpty ? null : countryName(p.country),
                  color: p.country == 'UZ' ? null : AnColors.good,
                ),
            ],
          ],
        ),

        // 6. Авторы.
        if (r.authors.isNotEmpty)
          _Section(
            title: t('an.s.authors'),
            icon: Icons.person_search_outlined,
            children: [
              _Note(t('an.authors_note', win)),
              for (final a in r.authors.take(15))
                CountBar(
                  label: a.name,
                  value: a.n,
                  max: r.authors.first.n,
                  valueText: _num(a.n),
                  sub: t('an.author_row', {
                    'n': _num(a.n),
                    'h': a.h,
                    'c': _num(a.citations),
                  }),
                  onTap: () => openLink(context, a.openAlexUrl),
                ),
            ],
          ),

        // 7. Журналы.
        _Section(
          title: t('an.s.journals'),
          icon: Icons.menu_book_outlined,
          children: [
            _BigNumber(value: _pct(r.doajShare), label: t('an.doaj_share')),
            _Note(t('an.journals_note')),
            for (final j in r.journals.take(15))
              CountBar(
                label: j.name,
                value: j.n,
                max: r.journals.isEmpty ? 0 : r.journals.first.n,
                valueText: _num(j.n),
                sub: [
                  _tr('an.jt.${j.type}', j.type),
                  if (j.publisher.isNotEmpty) j.publisher,
                  if (j.issn.isNotEmpty) 'ISSN ${j.issn}',
                ].join(' · '),
                trailing: j.doaj ? _Chip('DOAJ', AnColors.good) : null,
                onTap: () => openLink(context, 'https://openalex.org/${j.id}'),
              ),
          ],
        ),

        // 8. Сравнение.
        _Section(
          title: t('an.s.compare'),
          icon: Icons.compare_arrows,
          children: [
            _Note(t('an.compare_hint')),
            FilledButton.icon(
              key: const Key('an.compare_bottom'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: onCompare,
              icon: const Icon(Icons.compare_arrows),
              label: Text(t('an.compare')),
            ),
          ],
        ),

        // Надёжность данных.
        _Section(
          title: t('an.s.integrity'),
          icon: Icons.fact_check_outlined,
          children: [
            if (r.integrity.retracted != null) ...[
              _BigNumber(
                key: const Key('an.retracted'),
                value: _num(r.integrity.retracted!),
                label: t('an.retracted', win),
                color: r.integrity.retracted! > 0 ? scheme.error : null,
              ),
              _Note(r.integrity.retracted! > 0
                  ? t('an.retracted_note')
                  : t('an.retracted_none')),
            ],
            if (r.integrity.sourceTypes.isNotEmpty) ...[
              _BigNumber(
                value:
                    _pct(r.works > 0 ? r.integrity.repository / r.works : null),
                label: t('an.repo_share'),
              ),
              _Note(t('an.repo_note')),
            ],
          ],
        ),

        // Методика.
        _Section(
          title: t('an.s.method'),
          icon: Icons.science_outlined,
          children: [
            Text(
              t('an.method', {
                'date':
                    r.generated == null ? '—' : formatDate(r.generated!, lang),
                'from': r.windowFrom,
                'to': r.windowTo,
                'min': 100,
              }),
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => openLink(context,
                    'https://github.com/x9096730-spec/scinode/blob/main/analytics/README.md'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(t('an.method_link')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(40),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );
}

/// Публикации по годам: столбики (статьи / конференции / другое) и типы работ.
class _YearsBlock extends StatefulWidget {
  const _YearsBlock({required this.r});
  final OrgReport r;

  @override
  State<_YearsBlock> createState() => _YearsBlockState();
}

class _YearsBlockState extends State<_YearsBlock> {
  late int _sel = _defaultSel();

  int _defaultSel() {
    final ys = widget.r.years;
    final i = ys.indexWhere((y) => y.year == widget.r.windowTo);
    return i >= 0 ? i : ys.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.r;
    final ys = r.years;
    if (ys.isEmpty) return const SizedBox.shrink();
    final conf = AnColors.conference(context);
    final y = ys[_sel.clamp(0, ys.length - 1)];
    final partial = ys.last.year > r.windowTo;
    final totalTypes = r.types.fold<int>(0, (a, b) => a + b.n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YearBars(
          years: [for (final y in ys) y.year],
          parts: [
            for (final y in ys)
              [
                StackPart(y.article, AnColors.article(scheme)),
                StackPart(y.conference, conf),
                StackPart(y.other, AnColors.other(scheme)),
              ],
          ],
          selected: _sel,
          dimLast: partial,
          onSelect: (i) => setState(() => _sel = i),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            LegendDot(
                color: AnColors.article(scheme), label: t('an.l.article')),
            LegendDot(color: conf, label: t('an.l.conference')),
            LegendDot(color: AnColors.other(scheme), label: t('an.l.other')),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          t('an.year_total', {'year': y.year, 'n': _num(y.all)}),
          key: const Key('an.year_total'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        Text(
          '${t('an.l.article')}: ${_num(y.article)} · '
          '${t('an.l.conference')}: ${_num(y.conference)} · '
          '${t('an.l.other')}: ${_num(y.other)} · '
          '${t('an.s.oa')}: ${_pct(y.oaShare)}',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 4),
        _Note(t('an.tap_year')),
        if (partial) _Note(t('an.years_note', {'year': ys.last.year})),
        if (r.types.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(t('an.types'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final ty in r.types.take(6))
            CountBar(
              label: _tr('an.wt.${ty.id}', ty.name),
              value: ty.n,
              max: r.types.first.n,
              valueText: _pct(totalTypes > 0 ? ty.n / totalTypes : null),
            ),
        ],
      ],
    );
  }
}

class _PickOrgSheet extends StatefulWidget {
  const _PickOrgSheet({required this.index, required this.exclude});
  final AnalyticsIndex index;
  final String exclude;

  @override
  State<_PickOrgSheet> createState() => _PickOrgSheetState();
}

class _PickOrgSheetState extends State<_PickOrgSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final idx = widget.index;
    final list = [
      if (idx.national && widget.exclude != idx.country)
        OrgSummary(id: idx.country, name: idx.country, type: 'country'),
      for (final o in idx.orgs)
        if (o.id != widget.exclude && o.matches(_q.text)) o,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(t('an.compare_pick'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: t('an.search'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: mq.viewPadding.bottom + 16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final o = list[i];
                  return ListTile(
                    minTileHeight: 56,
                    title: Text(_orgName(o)),
                    subtitle: o.isCountry
                        ? null
                        : Text([
                            _typeLabel(o.type),
                            if (o.city.isNotEmpty) o.city,
                          ].join(' · ')),
                    onTap: () => Navigator.pop(context, o.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Сравнение двух организаций
// ---------------------------------------------------------------------------

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key, required this.a, required this.b});
  final String a;
  final String b;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late Future<List<OrgReport>> _f = _load();

  Future<List<OrgReport>> _load() => Future.wait([
        AnalyticsService.instance.report(widget.a),
        AnalyticsService.instance.report(widget.b),
      ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Strings.instance,
      builder: (context, _) => FutureBuilder<List<OrgReport>>(
        future: _f,
        builder: (context, snap) => Scaffold(
          appBar: AppBar(
            title: Text(t('an.s.compare')),
            actions: [
              if (snap.data != null)
                IconButton(
                  key: const Key('an.cmp_pdf_btn'),
                  tooltip: t('ap.pdf'),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () =>
                      openComparePdf(context, snap.data![0], snap.data![1]),
                ),
            ],
          ),
          body: _compareBody(context, snap),
        ),
      ),
    );
  }

  Widget _compareBody(
      BuildContext context, AsyncSnapshot<List<OrgReport>> snap) {
    {
      if (snap.hasError) {
        return _ErrorView(
          text: _err(snap.error!),
          onRetry: () => setState(() => _f = _load()),
        );
      }
      final d = snap.data;
      if (d == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return _CompareBody(a: d[0], b: d[1]);
    }
  }
}

class _CompareBody extends StatelessWidget {
  const _CompareBody({required this.a, required this.b});
  final OrgReport a;
  final OrgReport b;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ca = scheme.primary;
    final cb = AnColors.conference(context);
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final win = {'from': a.windowFrom, 'to': a.windowTo};
    int articles(OrgReport r) => r.years
        .where((y) => y.year >= r.windowFrom && y.year <= r.windowTo)
        .fold(0, (s, y) => s + y.article);

    final rows = <(String, String, String, double?, double?)>[
      (t('an.cmp.works', win), _num(a.works), _num(b.works), null, null),
      (t('an.cmp.articles'), _num(articles(a)), _num(articles(b)), null, null),
      if (a.citation.lead != null || b.citation.lead != null)
        (
          t('an.c.lead_top10'),
          _pct(a.citation.lead?.ppTop10),
          _pct(b.citation.lead?.ppTop10),
          a.citation.lead?.ppTop10,
          b.citation.lead?.ppTop10
        ),
      (
        t('an.c.top10'),
        _pct(a.citation.ppTop10),
        _pct(b.citation.ppTop10),
        a.citation.ppTop10,
        b.citation.ppTop10
      ),
      (
        t('an.c.top1'),
        _pct(a.citation.ppTop1),
        _pct(b.citation.ppTop1),
        a.citation.ppTop1,
        b.citation.ppTop1
      ),
      (
        t('an.c.cited'),
        _pct(a.citation.citedShare),
        _pct(b.citation.citedShare),
        a.citation.citedShare,
        b.citation.citedShare
      ),
      (
        t('an.c.above1'),
        _pct(a.citation.above1Share),
        _pct(b.citation.above1Share),
        a.citation.above1Share,
        b.citation.above1Share
      ),
      (t('an.cmp.oa'), _pct(a.oaShare), _pct(b.oaShare), a.oaShare, b.oaShare),
      (
        t('an.cmp.intl'),
        _pct(a.intlShare),
        _pct(b.intlShare),
        a.intlShare,
        b.intlShare
      ),
      (
        t('an.cmp.doaj'),
        _pct(a.doajShare),
        _pct(b.doajShare),
        a.doajShare,
        b.doajShare
      ),
      if (!a.org.isCountry && !b.org.isCountry)
        (t('an.cmp.h'), '${a.org.h}', '${b.org.h}', null, null),
      if (a.integrity.retracted != null && b.integrity.retracted != null)
        (
          t('an.cmp.retracted'),
          _num(a.integrity.retracted!),
          _num(b.integrity.retracted!),
          null,
          null
        ),
      (
        t('an.cmp.strong'),
        '${a.strongTopics.length}',
        '${b.strongTopics.length}',
        null,
        null
      ),
    ];

    final years = [
      for (final y in a.years)
        if (b.years.any((x) => x.year == y.year)) y.year,
    ];
    int allOf(OrgReport r, int year) =>
        r.years.firstWhere((y) => y.year == year).all;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottom),
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            LegendDot(color: ca, label: _orgName(a.org)),
            LegendDot(color: cb, label: _orgName(b.org)),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.$1,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(row.$2,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ca)),
                    ),
                    Expanded(
                      child: Text(row.$3,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: cb)),
                    ),
                  ],
                ),
                if (row.$4 != null && row.$5 != null) ...[
                  const SizedBox(height: 4),
                  _TwoBars(a: row.$4!, b: row.$5!, ca: ca, cb: cb),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(t('an.cmp.years'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _PairYears(
          years: years,
          a: [for (final y in years) allOf(a, y)],
          b: [for (final y in years) allOf(b, y)],
          ca: ca,
          cb: cb,
        ),
        const SizedBox(height: 16),
        InfoNote(text: t('an.disclaimer')),
      ],
    );
  }
}

class _TwoBars extends StatelessWidget {
  const _TwoBars(
      {required this.a, required this.b, required this.ca, required this.cb});
  final double a;
  final double b;
  final Color ca;
  final Color cb;

  @override
  Widget build(BuildContext context) {
    final top = [a, b, 0.0001].reduce((x, y) => x > y ? x : y);
    Widget bar(double v, Color c) => ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: v / top,
            minHeight: 8,
            color: c,
            backgroundColor: c.withAlpha(30),
          ),
        );
    return Column(
      children: [bar(a, ca), const SizedBox(height: 4), bar(b, cb)],
    );
  }
}

/// Пары столбиков по годам для сравнения.
class _PairYears extends StatelessWidget {
  const _PairYears({
    required this.years,
    required this.a,
    required this.b,
    required this.ca,
    required this.cb,
  });
  final List<int> years;
  final List<int> a;
  final List<int> b;
  final Color ca;
  final Color cb;

  @override
  Widget build(BuildContext context) {
    final top = [...a, ...b, 1].reduce((x, y) => x > y ? x : y);
    const h = 140.0;
    return SizedBox(
      height: h + 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < years.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Container(
                            height: h * a[i] / top + 1,
                            margin: const EdgeInsets.only(right: 1),
                            color: ca),
                      ),
                      Flexible(
                        child: Container(height: h * b[i] / top + 1, color: cb),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  YearLabel(years[i]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
