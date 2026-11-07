import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/analytics.dart';
import '../models/grant.dart' show formatDate, formatMoney;
import '../models/taxonomy.dart';
import '../strings.dart';
import 'report_pdf.dart' show Brand, ReportFonts, scinodeLogo;

// Фирменный PDF «Scinode Аналитика»: отчёт по организации и сравнение.
// Все тексты — на текущем языке интерфейса; графики рисуются прямо в PDF.

const _good = PdfColor.fromInt(0xFF10B981);
const _conf = PdfColor.fromInt(0xFFD97706);
const _otherC = PdfColor.fromInt(0xFF9A98B0);
const _countryC = PdfColor.fromInt(0xFFF97316);

String _tr(String key, String fallback) {
  final s = t(key);
  return s == key ? fallback : s;
}

/// Название организации на языке отчёта (страна — «Весь Узбекистан»).
String analyticsOrgName(OrgSummary o, String lang) =>
    o.isCountry ? t('an.country_card') : o.localName(lang);

String analyticsTypeLabel(String type) =>
    _tr('an.type.$type', t('an.type.other'));

/// Имя файла: Scinode_<название>_2026-11-05.pdf, без запрещённых символов.
String analyticsFileName(String name, DateTime d) {
  final clean = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final short = clean.length > 50 ? clean.substring(0, 50) : clean;
  String two(int x) => x.toString().padLeft(2, '0');
  return 'Scinode_${short}_${d.year}-${two(d.month)}-${two(d.day)}.pdf';
}

pw.ThemeData _theme(ReportFonts f) =>
    pw.ThemeData.withFont(base: f.regular, bold: f.bold).copyWith(
      defaultTextStyle: pw.TextStyle(
          font: f.regular, fontBold: f.bold, fontSize: 10, color: Brand.ink),
    );

/// PDF по одной организации (или по стране). [country] — для сравнения со
/// страной в разделе цитирования.
Future<Uint8List> buildOrgPdf(
  OrgReport r, {
  OrgReport? country,
  required ReportFonts fonts,
  required String lang,
}) {
  final b = _Pdf(lang);
  final name = analyticsOrgName(r.org, lang);
  final doc = pw.Document(
    theme: _theme(fonts),
    title: '${t('an.title')} — $name',
    author: 'Scinode',
    creator: 'Scinode',
  );
  doc.addPage(b.orgCover(r));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 28),
    header: (c) => b.header(name, r),
    footer: b.footer,
    build: (_) => [
      ...b.quality(r),
      ...b.years(r),
      ...b.oa(r),
      ...b.citation(r, country),
      ...b.topics(r),
      ...b.partners(r),
      ...b.authors(r),
      ...b.journals(r),
      ...b.sdg(r),
      ...b.languages(r),
      ...b.funding(r),
      ...b.integrity(r),
      ...b.history(r),
      ...b.method(r),
    ],
  ));
  return doc.save();
}

/// PDF «сравнение двух организаций».
Future<Uint8List> buildComparePdf(
  OrgReport a,
  OrgReport bR, {
  required ReportFonts fonts,
  required String lang,
}) {
  final b = _Pdf(lang);
  final na = analyticsOrgName(a.org, lang);
  final nb = analyticsOrgName(bR.org, lang);
  final doc = pw.Document(
    theme: _theme(fonts),
    title: '${t('an.s.compare')} — $na, $nb',
    author: 'Scinode',
    creator: 'Scinode',
  );
  doc.addPage(b.compareCover(a, bR));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 28),
    header: (c) => b.header('$na · $nb', a),
    footer: b.footer,
    build: (_) => [...b.compare(a, bR), ...b.method(a)],
  ));
  return doc.save();
}

class _Pdf {
  _Pdf(this.lang);
  final String lang;

  String n(int v) => formatMoney(v, '', lang);
  String p(double? v) => formatShare(v, lang);
  String date(DateTime? d) => d == null ? '—' : formatDate(d, lang);
  String period(OrgReport r) => '${r.windowFrom}–${r.windowTo}';

  // ---------------------------------------------------------------- обложки

  pw.Widget _brandHead() => pw.Container(
        height: 250,
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
            colors: [Brand.primary, Brand.primaryDark, Brand.navy],
          ),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            scinodeLogo(100),
            pw.SizedBox(height: 14),
            pw.Text('Scinode',
                style: pw.TextStyle(
                    fontSize: 34,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 1.5)),
            pw.SizedBox(height: 4),
            pw.Text(t('an.title'),
                style: const pw.TextStyle(
                    fontSize: 13, color: PdfColor.fromInt(0xFFD9D5FF))),
          ],
        ),
      );

  pw.Widget _brandFoot() => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 14),
        color: Brand.soft,
        child: pw.Row(
          children: [
            scinodeLogo(18),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(t('rp.pdf.made_in'),
                  style: const pw.TextStyle(fontSize: 9, color: Brand.muted)),
            ),
          ],
        ),
      );

  pw.Widget _info(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(k,
                  style: const pw.TextStyle(fontSize: 11, color: Brand.muted)),
            ),
            pw.Expanded(
                child: pw.Text(v, style: const pw.TextStyle(fontSize: 11))),
          ],
        ),
      );

  pw.Widget _kpi(String label, String value, PdfColor c) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: Brand.soft,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold, color: c)),
              pw.SizedBox(height: 2),
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
            ],
          ),
        ),
      );

  pw.Page orgCover(OrgReport r) {
    final o = r.org;
    final name = analyticsOrgName(o, lang);
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _brandHead(),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(56, 40, 56, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(t(o.isCountry ? 'ap.kind_country' : 'ap.kind_org'),
                      style: pw.TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: Brand.primary,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(name,
                      maxLines: 3,
                      style: pw.TextStyle(
                          fontSize: 26, fontWeight: pw.FontWeight.bold)),
                  if (!o.isCountry && name != o.name) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(o.name,
                        style: const pw.TextStyle(
                            fontSize: 12, color: Brand.muted)),
                  ],
                  pw.SizedBox(height: 14),
                  pw.Container(width: 64, height: 4, color: Brand.primary),
                  pw.SizedBox(height: 20),
                  _info(t('ap.type'),
                      analyticsTypeLabel(o.isCountry ? 'country' : o.type)),
                  if (o.city.isNotEmpty) _info(t('ap.city'), o.city),
                  if (o.established != null)
                    _info(t('ap.founded'), '${o.established}'),
                  _info(t('ap.period'), period(r)),
                  _info(t('ap.data_date'), date(r.generated)),
                  _info(t('ap.source'), t('ap.source_v')),
                  pw.SizedBox(height: 22),
                  pw.Row(children: [
                    _kpi(
                        t('an.stat.works',
                            {'from': r.windowFrom, 'to': r.windowTo}),
                        n(r.works),
                        Brand.primary),
                    r.citation.lead != null
                        ? _kpi(t('an.c.lead_top10'),
                            p(r.citation.lead!.ppTop10), _good)
                        : _kpi(t('an.c.top10'), p(r.citation.ppTop10), _good),
                    _kpi(t('an.s.oa'), p(r.oaShare), Brand.open),
                    _kpi(t('an.cmp.intl'), p(r.intlShare), _countryC),
                  ]),
                  pw.SizedBox(height: 22),
                  _note(t('an.disclaimer')),
                ],
              ),
            ),
          ),
          _brandFoot(),
        ],
      ),
    );
  }

  pw.Page compareCover(OrgReport a, OrgReport b) {
    final na = analyticsOrgName(a.org, lang);
    final nb = analyticsOrgName(b.org, lang);
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _brandHead(),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(56, 40, 56, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(t('ap.kind_compare'),
                      style: pw.TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: Brand.primary,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  _dotName(na, Brand.primary),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(t('ap.vs'),
                        style: const pw.TextStyle(
                            fontSize: 12, color: Brand.muted)),
                  ),
                  _dotName(nb, _conf),
                  pw.SizedBox(height: 16),
                  pw.Container(width: 64, height: 4, color: Brand.primary),
                  pw.SizedBox(height: 20),
                  _info(t('ap.period'), period(a)),
                  _info(t('ap.data_date'), date(a.generated)),
                  _info(t('ap.source'), t('ap.source_v')),
                  pw.SizedBox(height: 22),
                  _note(t('an.disclaimer')),
                ],
              ),
            ),
          ),
          _brandFoot(),
        ],
      ),
    );
  }

  pw.Widget _dotName(String s, PdfColor c) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8, right: 10),
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(color: c, shape: pw.BoxShape.circle),
          ),
          pw.Expanded(
            child: pw.Text(s,
                maxLines: 3,
                style:
                    pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      );

  // ------------------------------------------------- шапка и подвал страниц

  pw.Widget header(String title, OrgReport r) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: Brand.line)),
        ),
        child: pw.Row(
          children: [
            scinodeLogo(14),
            pw.SizedBox(width: 6),
            pw.Text('Scinode',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: Brand.primary,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Text('$title · ${period(r)}',
                  maxLines: 1,
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
            ),
          ],
        ),
      );

  pw.Widget footer(pw.Context c) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          children: [
            pw.Text('Scinode · OpenAlex',
                style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
            pw.Spacer(),
            pw.Text(t('rp.pdf.page', {'p': c.pageNumber, 'n': c.pagesCount}),
                style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
          ],
        ),
      );

  // ------------------------------------------------------------ элементы

  pw.Widget _h1(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 8),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 16, color: Brand.primary),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(s,
                style:
                    pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          ),
        ]),
      );

  pw.Widget _note(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(s,
            style: const pw.TextStyle(fontSize: 8.5, color: Brand.muted)),
      );

  pw.Widget _big(String value, String label, {PdfColor c = Brand.primary}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold, color: c)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      );

  pw.Widget _table(List<String> head, List<List<String>> rows,
          {Map<int, pw.TableColumnWidth>? widths, Set<int> right = const {}}) =>
      pw.TableHelper.fromTextArray(
        headers: head,
        data: rows,
        // Все колонки — доли ширины страницы: иначе узкие колонки берут
        // ширину по данным и заголовок рвётся («Jaho/n»).
        columnWidths: {
          for (var i = 0; i < head.length; i++)
            i: widths?[i] ?? const pw.FlexColumnWidth(1),
        },
        border: null,
        headerStyle: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: Brand.primary),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        cellAlignment: pw.Alignment.centerLeft,
        cellAlignments: {for (final i in right) i: pw.Alignment.centerRight},
        headerAlignments: {for (final i in right) i: pw.Alignment.centerRight},
        headerAlignment: pw.Alignment.centerLeft,
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
        oddRowDecoration: const pw.BoxDecoration(color: Brand.soft),
        rowDecoration: const pw.BoxDecoration(
            border:
                pw.Border(bottom: pw.BorderSide(color: Brand.line, width: .5))),
      );

  pw.Widget _legend(List<(String, PdfColor)> items) => pw.Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final (s, c) in items)
            pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              pw.Container(
                  width: 8,
                  height: 8,
                  decoration:
                      pw.BoxDecoration(color: c, shape: pw.BoxShape.circle)),
              pw.SizedBox(width: 4),
              pw.Text(s, style: const pw.TextStyle(fontSize: 8.5)),
            ]),
        ],
      );

  /// Столбики по годам: каждая колонка — список частей (снизу вверх).
  pw.Widget _yearChart(List<int> years, List<List<(int, PdfColor)>> parts,
      {double height = 120, int? dim}) {
    final totals = [for (final x in parts) x.fold<int>(0, (a, b) => a + b.$1)];
    final top = max(1, totals.fold<int>(0, max));
    return pw.SizedBox(
      height: height + 26,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < years.length; i++)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 3),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(n(totals[i]),
                        style: const pw.TextStyle(fontSize: 6.5)),
                    pw.SizedBox(height: 2),
                    pw.Opacity(
                      opacity: dim == i ? 0.45 : 1,
                      child: pw.Column(children: [
                        for (final (v, c) in parts[i].reversed)
                          pw.Container(height: height * v / top, color: c),
                      ]),
                    ),
                    if (totals[i] == 0)
                      pw.Container(height: 1, color: Brand.line),
                    pw.SizedBox(height: 3),
                    pw.Text('${years[i]}',
                        style: const pw.TextStyle(
                            fontSize: 7, color: Brand.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Полоска доли с метками «мир» (серая) и «страна» (оранжевая).
  pw.Widget _share(String label, double? v,
      {double scale = 1, double? world, double? country}) {
    double f(double? x) => x == null ? 0 : (x / scale).clamp(0.0, 1.0);
    final good = world != null && v != null && v >= world;
    final c = good ? _good : Brand.primary;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Expanded(
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
            pw.Text(p(v),
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold, color: c)),
          ]),
          pw.SizedBox(height: 4),
          pw.LayoutBuilder(builder: (ctx, cons) {
            final w = cons!.maxWidth;
            // Метки только для известных значений: пустой непозиционированный
            // элемент обнулил бы размер Stack и полоска не нарисовалась бы.
            pw.Widget mark(double x, PdfColor col) => pw.Positioned(
                  left: (w * f(x) - 1).clamp(0, w - 2),
                  top: 0,
                  child: pw.Container(width: 2, height: 12, color: col),
                );
            return pw.SizedBox(
              height: 12,
              child: pw.Stack(children: [
                pw.Positioned(
                  left: 0,
                  top: 3,
                  child: pw.Container(
                      width: w,
                      height: 6,
                      decoration: pw.BoxDecoration(
                          color: Brand.soft,
                          borderRadius: pw.BorderRadius.circular(3))),
                ),
                pw.Positioned(
                  left: 0,
                  top: 3,
                  child: pw.Container(
                      width: max(0.5, w * f(v)),
                      height: 6,
                      decoration: pw.BoxDecoration(
                          color: c, borderRadius: pw.BorderRadius.circular(3))),
                ),
                if (world != null) mark(world, Brand.muted),
                if (country != null) mark(country, _countryC),
              ]),
            );
          }),
          if (world != null || country != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(
                [
                  if (world != null) t('an.world', {'v': p(world)}),
                  if (country != null) t('an.country_v', {'v': p(country)}),
                ].join(' · '),
                style: const pw.TextStyle(fontSize: 8, color: Brand.muted),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ разделы

  List<pw.Widget> years(OrgReport r) {
    final ys = r.years;
    if (ys.isEmpty) return [];
    final partial = ys.last.year > r.windowTo;
    final total = r.types.fold<int>(0, (a, b) => a + b.n);
    return [
      _h1('1. ${t('an.s.years')}'),
      _yearChart(
        [for (final y in ys) y.year],
        [
          for (final y in ys)
            [
              (y.article, Brand.primary),
              (y.conference, _conf),
              (y.other, _otherC)
            ],
        ],
        dim: partial ? ys.length - 1 : null,
      ),
      pw.SizedBox(height: 6),
      _legend([
        (t('an.l.article'), Brand.primary),
        (t('an.l.conference'), _conf),
        (t('an.l.other'), _otherC),
      ]),
      if (partial) _note(t('an.years_note', {'year': ys.last.year})),
      pw.SizedBox(height: 8),
      _table(
        [
          t('ap.year'),
          t('ap.total'),
          t('an.l.article'),
          t('an.l.conference'),
          t('an.l.other'),
          t('an.s.oa'),
        ],
        [
          for (final y in ys.reversed)
            [
              '${y.year}',
              n(y.all),
              n(y.article),
              n(y.conference),
              n(y.other),
              p(y.oaShare),
            ],
        ],
        right: {1, 2, 3, 4, 5},
      ),
      if (r.types.isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text(t('an.types'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        _table(
          [t('an.types'), t('ap.works'), t('ap.share')],
          [
            for (final ty in r.types.take(8))
              [
                _tr('an.wt.${ty.id}', ty.name),
                n(ty.n),
                p(total > 0 ? ty.n / total : null),
              ],
          ],
          right: {1, 2},
        ),
      ],
    ];
  }

  List<pw.Widget> oa(OrgReport r) => [
        _h1('2. ${t('an.s.oa')}'),
        _big(p(r.oaShare), t('an.oa_share'), c: _good),
        _table(
          [t('an.s.oa'), t('ap.works'), t('ap.share')],
          [
            for (final s in r.oaStatus)
              [
                _tr('an.oa.${s.id}', s.name),
                n(s.n),
                p(r.works > 0 ? s.n / r.works : null),
              ],
          ],
          widths: {0: const pw.FlexColumnWidth(3)},
          right: {1, 2},
        ),
      ];

  List<pw.Widget> citation(OrgReport r, OrgReport? c) {
    final cc = c?.citation;
    return [
      _h1('3. ${t('an.s.cite')}'),
      _note(t('an.cite_note')),
      if (r.citation.lead != null) ...[
        _share(t('an.c.lead_top10'), r.citation.lead!.ppTop10,
            scale: 0.2, world: 0.10),
        _note(t('an.lead_note', {
          'n': n(r.citation.lead!.works),
          'all': n(r.works),
          'p': p(r.citation.lead!.share),
        })),
      ],
      _share(t('an.c.top10'), r.citation.ppTop10,
          scale: 0.2, world: 0.10, country: cc?.ppTop10),
      _share(t('an.c.top1'), r.citation.ppTop1,
          scale: 0.02, world: 0.01, country: cc?.ppTop1),
      _share(t('an.c.cited'), r.citation.citedShare, country: cc?.citedShare),
      _share(t('an.c.above1'), r.citation.above1Share,
          scale: 0.5, country: cc?.above1Share),
      _table(
        [
          t('ap.indicator'),
          t('ap.org'),
          if (c != null) t('ap.country'),
          t('ap.world')
        ],
        [
          if (r.citation.lead != null)
            [
              t('an.c.lead_top10'),
              p(r.citation.lead!.ppTop10),
              if (c != null) '—',
              p(0.10)
            ],
          [
            t('an.c.top10'),
            p(r.citation.ppTop10),
            if (c != null) p(cc!.ppTop10),
            p(0.10)
          ],
          [
            t('an.c.top1'),
            p(r.citation.ppTop1),
            if (c != null) p(cc!.ppTop1),
            p(0.01)
          ],
          [
            t('an.c.cited'),
            p(r.citation.citedShare),
            if (c != null) p(cc!.citedShare),
            '—'
          ],
          [
            t('an.c.above1'),
            p(r.citation.above1Share),
            if (c != null) p(cc!.above1Share),
            '—'
          ],
        ],
        widths: {0: const pw.FlexColumnWidth(3)},
        right: {1, 2, 3},
      ),
      if (r.citation.megaWorks > 0)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: _note(t('an.mega_note', {
            'n': n(r.citation.megaWorks),
            't': n(r.citation.megaTop10),
            'p': p(r.citation.ppTop10WithoutMega),
          })),
        ),
    ];
  }

  List<pw.Widget> topics(OrgReport r) => [
        _h1('4. ${t('an.s.topics')}'),
        _note(t('an.topics_note', {'n': 30})),
        if (r.strongTopics.isEmpty) _note(t('an.no_strong')),
        _table(
          [
            t('ap.area'),
            t('ap.works'),
            if (r.topics.any((x) => x.lead != null)) t('ap.own'),
            if (r.topics.any((x) => x.lead != null))
              t('ap.own_top10')
            else
              t('an.c.top10'),
            t('ap.mark'),
          ],
          [
            for (final tp in r.topics.take(15))
              [
                localSubfieldName(tp.id, tp.name),
                n(tp.n),
                if (tp.lead != null) n(tp.lead!),
                p(tp.lead != null ? tp.leadPpTop10 : tp.ppTop10),
                tp.strong
                    ? t('an.strong')
                    : tp.mostlyGuest
                        ? t('an.guest')
                        : '',
              ],
          ],
          widths: {
            0: const pw.FlexColumnWidth(3),
            4: const pw.FlexColumnWidth(1.8),
          },
          right: {1, 2, 3},
        ),
      ];

  List<pw.Widget> partners(OrgReport r) => [
        _h1('5. ${t('an.s.partners')}'),
        _big(p(r.intlShare), t('an.intl'), c: _countryC),
        if (r.countries.isNotEmpty) ...[
          pw.Text(t('an.countries'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _table(
            [t('ap.country'), t('ap.works')],
            [
              for (final x in r.countries.take(12))
                [
                  countryName(x.id) == x.id ? x.name : countryName(x.id),
                  n(x.n)
                ],
            ],
            widths: {0: const pw.FlexColumnWidth(3)},
            right: {1},
          ),
          pw.SizedBox(height: 10),
        ],
        if (r.partners.isNotEmpty) ...[
          pw.Text(t('an.partner_orgs'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _table(
            [t('ap.org'), t('ap.country'), t('ap.works')],
            [
              for (final x in r.partners.take(15))
                [
                  x.name,
                  x.country.isEmpty ? '—' : countryName(x.country),
                  n(x.n),
                ],
            ],
            widths: {0: const pw.FlexColumnWidth(3.2)},
            right: {2},
          ),
        ],
      ];

  List<pw.Widget> authors(OrgReport r) => r.authors.isEmpty
      ? []
      : [
          _h1('6. ${t('an.s.authors')}'),
          _note(t('an.authors_note', {'from': r.windowFrom, 'to': r.windowTo})),
          _table(
            [t('ap.author'), t('ap.here'), 'h', t('ap.cites')],
            [
              for (final a in r.authors.take(20))
                [
                  r.isDuplicateAuthor(a) ? '${a.name} *' : a.name,
                  n(a.n),
                  '${a.h}',
                  n(a.citations)
                ],
            ],
            widths: {0: const pw.FlexColumnWidth(3)},
            right: {1, 2, 3},
          ),
          if (r.duplicateAuthorNames.isNotEmpty)
            _note('* ${t('an.author_dup')}'),
        ];

  List<pw.Widget> journals(OrgReport r) => [
        _h1('7. ${t('an.s.journals')}'),
        _big(p(r.doajShare), t('an.doaj_share'), c: _good),
        _note(t('an.journals_note')),
        _table(
          [
            t('ap.source_name'),
            t('ap.type'),
            'DOAJ',
            t('ap.works'),
            t('ap.mark'),
          ],
          [
            for (final j in r.journals.take(20))
              [
                [j.name, if (j.issn.isNotEmpty) 'ISSN ${j.issn}'].join(' · '),
                _tr('an.jt.${j.type}', j.type),
                j.doaj ? t('ap.yes') : '',
                n(j.n),
                [
                  if (j.warning && j.crossref == false) t('an.j.no_crossref'),
                  if (j.warning && j.growthSharp)
                    t('an.j.growth', {
                      'a': n(j.growthBefore),
                      'b': n(j.growthWorks),
                      'y': j.growthYear ?? '',
                    }),
                ].join('; '),
              ],
          ],
          widths: {
            0: const pw.FlexColumnWidth(3),
            4: const pw.FlexColumnWidth(2),
          },
          right: {3},
        ),
      ];

  List<pw.Widget> quality(OrgReport r) {
    final q = r.quality;
    if (q == null) return [];
    final c = switch (q.level) {
      'good' => _good,
      'medium' => _countryC,
      _ => Brand.late,
    };
    final pp = r.citation.lead?.ppTop10 ?? r.citation.ppTop10;
    return [
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: c, width: 1),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${t('an.q.title')}: ${t('an.q.${q.level}')}',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: c)),
            pw.SizedBox(height: 4),
            for (final reason in q.reasons)
              pw.Text('• ${_tr('an.q.r.$reason', reason)}',
                  style: const pw.TextStyle(fontSize: 8.5)),
            if (q.ciLow != null && q.ciHigh != null && pp != null)
              pw.Text(
                  t('an.q.ci',
                      {'p': p(pp), 'lo': p(q.ciLow), 'hi': p(q.ciHigh)}),
                  style: const pw.TextStyle(fontSize: 8.5)),
            pw.Text(
                '${t('an.q.doi')}: ${p(q.doiShare)} · ${t('an.q.orcid')}: ${p(q.orcidShare)}',
                style: const pw.TextStyle(fontSize: 8.5)),
            pw.SizedBox(height: 3),
            pw.Text(t('an.q.note'),
                style: const pw.TextStyle(fontSize: 7.5, color: Brand.muted)),
          ],
        ),
      ),
    ];
  }

  List<pw.Widget> history(OrgReport r) {
    final h = r.history;
    if (h.isEmpty) return [];
    if (h.length < 2) {
      return [
        _h1(t('an.s.history')),
        _note(t('an.h.first', {'date': date(h.first.date)})),
      ];
    }
    final rows = h.reversed.take(12).toList();
    String ch(int i, double? Function(HistoryPoint) f) =>
        i + 1 < rows.length && rows[i].sameWindow(rows[i + 1])
            ? formatPpChange(f(rows[i]), f(rows[i + 1]), lang)
            : '';
    double? top(HistoryPoint x) => x.leadPpTop10 ?? x.ppTop10;
    return [
      _h1(t('an.s.history')),
      _note(t('an.h.note')),
      _table(
        [
          t('an.h.date'),
          t('ap.period'),
          t('ap.works'),
          r.citation.lead != null ? t('an.c.lead_top10') : t('an.c.top10'),
          t('an.cmp.oa'),
          t('an.q.title'),
        ],
        [
          for (var i = 0; i < rows.length; i++)
            [
              date(rows[i].date),
              '${rows[i].windowFrom}–${rows[i].windowTo}',
              n(rows[i].works),
              [p(top(rows[i])), ch(i, top)]
                  .where((x) => x.isNotEmpty)
                  .join(' '),
              [p(rows[i].oaShare), ch(i, (x) => x.oaShare)]
                  .where((x) => x.isNotEmpty)
                  .join(' '),
              _tr('an.q.short.${rows[i].level}', rows[i].level),
            ],
        ],
        right: {2},
      ),
    ];
  }

  List<pw.Widget> sdg(OrgReport r) {
    final s = r.sdg;
    if (s == null || s.goals.isEmpty) return [];
    return [
      _h1('8. ${t('an.s.sdg')}'),
      _big(p(s.share), t('an.sdg_share'), c: _good),
      _note(t('an.sdg_note')),
      _table(
        [t('an.s.sdg'), t('ap.works'), t('ap.share')],
        [
          for (final g in s.goals)
            [
              '${g.$1}. ${t('an.sdg.${g.$1}')}',
              n(g.$2),
              p(s.works > 0 ? g.$2 / s.works : null),
            ],
        ],
        widths: {0: const pw.FlexColumnWidth(3)},
        right: {1, 2},
      ),
    ];
  }

  List<pw.Widget> languages(OrgReport r) => r.mainLanguages.isEmpty
      ? []
      : [
          _h1('9. ${t('an.s.lang')}'),
          _note(t('an.lang_note')),
          _table(
            [t('an.s.lang'), t('ap.works'), t('ap.share')],
            [
              for (final l in r.mainLanguages.take(10))
                [
                  _tr('an.lang.${l.id}', l.name.isEmpty ? l.id : l.name),
                  n(l.n),
                  p(r.works > 0 ? l.n / r.works : null),
                ],
            ],
            widths: {0: const pw.FlexColumnWidth(3)},
            right: {1, 2},
          ),
        ];

  List<pw.Widget> funding(OrgReport r) {
    final f = r.funding;
    final a = r.apc;
    if (f == null && a == null) return [];
    return [
      _h1('10. ${t('an.s.funding')}'),
      if (f != null) ...[
        _big(p(f.share), t('an.funded_share')),
        _note(t('an.funding_note')),
        if (f.top.isNotEmpty)
          _table(
            [t('an.funders'), t('ap.country'), t('ap.works')],
            [
              for (final x in f.top.take(15))
                [
                  x.name,
                  x.country.isEmpty ? '' : countryName(x.country),
                  n(x.n)
                ],
            ],
            widths: {0: const pw.FlexColumnWidth(3)},
            right: {2},
          ),
        pw.SizedBox(height: 8),
      ],
      if (a != null) ...[
        if (a.lead != null)
          _big(formatMoney(a.lead!.usd, 'USD', lang),
              t('an.apc_lead', {'n': n(a.lead!.works)})),
        _big(
            formatMoney(a.usd, 'USD', lang), t('an.apc_all', {'n': n(a.works)}),
            c: Brand.muted),
        _note(t('an.apc_note')),
        if (r.org.isCountry) _note(t('an.apc_country_note')),
      ],
    ];
  }

  List<pw.Widget> _prolific(Prolific pr) => [
        pw.SizedBox(height: 8),
        _big('${pr.authors.length}', t('an.prolific', {'t': pr.threshold}),
            c: pr.authors.isEmpty ? Brand.primary : _countryC),
        _note(t('an.prolific_note', {'n': pr.checked})),
        if (pr.authors.isEmpty)
          _note(t('an.prolific_none'))
        else
          _table(
            [t('ap.author'), t('ap.mark')],
            [
              for (final (i, a) in pr.authors.indexed)
                [
                  [
                    t('an.prolific_author', {'i': i + 1}),
                    a.home ? t('an.prolific_is_home') : t('an.prolific_abroad'),
                  ].join('\n'),
                  t('an.prolific_row', {
                    'max': n(a.max),
                    'y': a.maxYear,
                    'k': a.yearsOver,
                    'n': n(a.n),
                  }),
                ],
            ],
            widths: {0: const pw.FlexColumnWidth(1.6)},
          ),
        if (pr.authors.isNotEmpty)
          _note(t('an.prolific_home', {
            'h': pr.home,
            'a': pr.authors.length - pr.home,
          })),
      ];

  List<pw.Widget> integrity(OrgReport r) => [
        _h1(t('an.s.integrity')),
        if (r.integrity.retracted != null) ...[
          _big(n(r.integrity.retracted!),
              t('an.retracted', {'from': r.windowFrom, 'to': r.windowTo}),
              c: r.integrity.retracted! > 0 ? Brand.late : Brand.primary),
          _note(r.integrity.retracted! > 0
              ? t('an.retracted_note')
              : t('an.retracted_none')),
        ],
        if (r.integrity.sourceTypes.isNotEmpty) ...[
          _big(p(r.works > 0 ? r.integrity.repository / r.works : null),
              t('an.repo_share')),
          _note(t('an.repo_note')),
        ],
        if (r.prolific != null) ..._prolific(r.prolific!),
        if (r.citationCheck != null) ..._citationCheck(r.citationCheck!),
      ];

  String _flag(String f, CheckedWork w) {
    final name = _tr('an.cc.f.$f', f);
    return switch (f) {
      'own_institution' => '$name: ${p(w.ownShare)}',
      'one_institution' => '$name: ${p(w.topShare)} (${w.topName})',
      'author_self' => '$name: ${p(w.authorScShare)}',
      'journal_self' => '$name: ${p(w.journalScShare)}',
      _ => name,
    };
  }

  List<pw.Widget> _citationCheck(CitationCheck c) {
    final flagged = [
      for (final w in c.works)
        if (w.flags.isNotEmpty) w,
    ];
    return [
      pw.SizedBox(height: 8),
      pw.Text(t('an.cc.title', {'n': c.checked}),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      _note(t('an.cc.note')),
      _table(
        [t('ap.indicator'), t('ap.share')],
        [
          [t('an.cc.author_sc'), p(c.authorScShare)],
          [t('an.cc.journal_sc'), p(c.journalScShare)],
          [t('an.cc.own'), p(c.ownShare)],
        ],
        widths: {0: const pw.FlexColumnWidth(3)},
        right: {1},
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        flagged.isEmpty
            ? t('an.cc.none')
            : t('an.cc.flagged', {'n': flagged.length, 'all': c.checked}),
        style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: flagged.isEmpty ? _good : _countryC),
      ),
      if (flagged.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        _table(
          [t('ap.work'), t('ap.cites'), t('ap.mark')],
          [
            for (final w in flagged)
              [
                [
                  w.title,
                  [
                    if (w.year != null) '${w.year}',
                    if (w.source.isNotEmpty) w.source,
                    if (w.doi.isNotEmpty) 'doi:${w.doi}',
                  ].join(' · '),
                ].join('\n'),
                n(w.cited),
                w.flags.map((f) => _flag(f, w)).join('; '),
              ],
          ],
          widths: {
            0: const pw.FlexColumnWidth(3.2),
            2: const pw.FlexColumnWidth(2.2),
          },
          right: {1},
        ),
      ],
    ];
  }

  List<pw.Widget> method(OrgReport r) => [
        _h1(t('an.s.method')),
        pw.Text(
          t('an.method', {
            'date': date(r.generated),
            'from': r.windowFrom,
            'to': r.windowTo,
            'min': 100,
          }),
          style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
        ),
        pw.SizedBox(height: 6),
        _note(t('an.disclaimer')),
        pw.UrlLink(
          destination:
              'https://github.com/x9096730-spec/scinode/blob/main/analytics/README.md',
          child: pw.Text(t('an.method_link'),
              style: const pw.TextStyle(
                  fontSize: 9,
                  color: Brand.primary,
                  decoration: pw.TextDecoration.underline)),
        ),
      ];

  List<pw.Widget> compare(OrgReport a, OrgReport b) {
    int articles(OrgReport r) => r.years
        .where((y) => y.year >= r.windowFrom && y.year <= r.windowTo)
        .fold(0, (s, y) => s + y.article);
    final na = analyticsOrgName(a.org, lang);
    final nb = analyticsOrgName(b.org, lang);
    final win = {'from': a.windowFrom, 'to': a.windowTo};
    final years = [
      for (final y in a.years)
        if (b.years.any((x) => x.year == y.year)) y.year,
    ];
    int allOf(OrgReport r, int year) =>
        r.years.firstWhere((y) => y.year == year).all;
    return [
      _h1(t('an.s.compare')),
      _legend([(na, Brand.primary), (nb, _conf)]),
      pw.SizedBox(height: 8),
      _table(
        [t('ap.indicator'), na, nb],
        [
          [t('an.cmp.works', win), n(a.works), n(b.works)],
          [t('an.cmp.articles'), n(articles(a)), n(articles(b))],
          if (a.citation.lead != null || b.citation.lead != null)
            [
              t('an.c.lead_top10'),
              p(a.citation.lead?.ppTop10),
              p(b.citation.lead?.ppTop10)
            ],
          [t('an.c.top10'), p(a.citation.ppTop10), p(b.citation.ppTop10)],
          [t('an.c.top1'), p(a.citation.ppTop1), p(b.citation.ppTop1)],
          [t('an.c.cited'), p(a.citation.citedShare), p(b.citation.citedShare)],
          [
            t('an.c.above1'),
            p(a.citation.above1Share),
            p(b.citation.above1Share)
          ],
          [t('an.cmp.oa'), p(a.oaShare), p(b.oaShare)],
          [t('an.cmp.intl'), p(a.intlShare), p(b.intlShare)],
          [t('an.cmp.doaj'), p(a.doajShare), p(b.doajShare)],
          if (!a.org.isCountry && !b.org.isCountry)
            [t('an.cmp.h'), '${a.org.h}', '${b.org.h}'],
          if (a.citationCheck != null && b.citationCheck != null) ...[
            [
              t('an.cc.author_sc'),
              p(a.citationCheck!.authorScShare),
              p(b.citationCheck!.authorScShare)
            ],
            [
              t('an.cmp.flagged'),
              '${a.citationCheck!.flagged} / ${a.citationCheck!.checked}',
              '${b.citationCheck!.flagged} / ${b.citationCheck!.checked}'
            ],
          ],
          if (a.integrity.retracted != null && b.integrity.retracted != null)
            [
              t('an.cmp.retracted'),
              n(a.integrity.retracted!),
              n(b.integrity.retracted!)
            ],
          [
            t('an.cmp.strong'),
            '${a.strongTopics.length}',
            '${b.strongTopics.length}'
          ],
          if (a.quality != null && b.quality != null)
            [
              t('an.cmp.quality'),
              t('an.q.short.${a.quality!.level}'),
              t('an.q.short.${b.quality!.level}')
            ],
          if (a.sdg != null && b.sdg != null)
            [t('an.cmp.sdg'), p(a.sdg!.share), p(b.sdg!.share)],
          if (a.languages.isNotEmpty && b.languages.isNotEmpty)
            [
              t('an.cmp.uz'),
              p(languageShare(a, 'uz')),
              p(languageShare(b, 'uz'))
            ],
          if (a.funding != null && b.funding != null)
            [t('an.cmp.funded'), p(a.funding!.share), p(b.funding!.share)],
          if (a.apc?.lead != null && b.apc?.lead != null)
            [
              t('an.cmp.apc'),
              formatMoney(a.apc!.lead!.usd, 'USD', lang),
              formatMoney(b.apc!.lead!.usd, 'USD', lang)
            ],
          if (a.prolific != null && b.prolific != null)
            [
              t('an.cmp.prolific'),
              '${a.prolific!.authors.length}',
              '${b.prolific!.authors.length}'
            ],
        ],
        widths: {0: const pw.FlexColumnWidth(2.6)},
        right: {1, 2},
      ),
      _h1(t('an.cmp.years')),
      _pairChart(years, [for (final y in years) allOf(a, y)],
          [for (final y in years) allOf(b, y)]),
      if (years.isNotEmpty && years.last > a.windowTo)
        _note(t('an.years_note', {'year': years.last})),
      pw.SizedBox(height: 8),
      _table(
        [t('ap.year'), na, nb],
        [
          for (final y in years.reversed)
            ['$y', n(allOf(a, y)), n(allOf(b, y))],
        ],
        right: {1, 2},
      ),
      _h1(t('an.s.topics')),
      _table(
        [t('ap.org'), t('an.s.topics')],
        [
          [
            na,
            a.strongTopics.isEmpty
                ? '—'
                : a.strongTopics
                    .map((x) => localSubfieldName(x.id, x.name))
                    .join(', ')
          ],
          [
            nb,
            b.strongTopics.isEmpty
                ? '—'
                : b.strongTopics
                    .map((x) => localSubfieldName(x.id, x.name))
                    .join(', ')
          ],
        ],
        widths: {
          0: const pw.FlexColumnWidth(1.4),
          1: const pw.FlexColumnWidth(3)
        },
      ),
    ];
  }

  pw.Widget _pairChart(List<int> years, List<int> a, List<int> b) {
    final top = [...a, ...b, 1].reduce(max);
    const h = 120.0;
    return pw.SizedBox(
      height: h + 16,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < years.length; i++)
            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Container(
                          width: 9,
                          height: h * a[i] / top + .5,
                          color: Brand.primary),
                      pw.SizedBox(width: 1),
                      pw.Container(
                          width: 9, height: h * b[i] / top + .5, color: _conf),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text('${years[i]}',
                      style:
                          const pw.TextStyle(fontSize: 7, color: Brand.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
