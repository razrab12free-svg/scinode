import 'dart:math';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/board.dart';
import '../models/board_report.dart';
import '../models/grant.dart' show formatDate;
import '../strings.dart';

/// Фирменные цвета Scinode (seed темы 0xFF5B4BFF и цвета логотипа).
class Brand {
  static const primary = PdfColor.fromInt(0xFF5B4BFF);
  static const primaryDark = PdfColor.fromInt(0xFF2E2678);
  static const navy = PdfColor.fromInt(0xFF0A0C28);
  static const soft = PdfColor.fromInt(0xFFEEECFF);
  static const ink = PdfColor.fromInt(0xFF1C1B2E);
  static const muted = PdfColor.fromInt(0xFF6B6A80);
  static const line = PdfColor.fromInt(0xFFDDDBEE);
  static const done = PdfColor.fromInt(0xFF16A34A);
  static const late = PdfColor.fromInt(0xFFDC2626);
  static const open = PdfColor.fromInt(0xFF3B82F6);
}

/// Шрифты PDF (кириллица и узбекская латиница).
class ReportFonts {
  const ReportFonts(this.regular, this.bold);
  final pw.Font regular;
  final pw.Font bold;

  factory ReportFonts.fromBytes(ByteData regular, ByteData bold) =>
      ReportFonts(pw.Font.ttf(regular), pw.Font.ttf(bold));
}

/// Собирает PDF-отчёт по доске.
///
/// [names] — имена участников по uid. Тексты — на текущем языке интерфейса.
Future<Uint8List> buildReportPdf(
  BoardReport r, {
  required Set<ReportSection> sections,
  required Map<String, String> names,
  required ReportFonts fonts,
  required String lang,
}) {
  final b = _Builder(r, names, lang);
  final theme =
      pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold).copyWith(
    defaultTextStyle: pw.TextStyle(
        font: fonts.regular,
        fontBold: fonts.bold,
        fontSize: 10,
        color: Brand.ink),
  );
  final doc = pw.Document(
    theme: theme,
    title: '${t('rp.pdf.file')} — ${r.board.name}',
    author: 'Scinode',
    creator: 'Scinode',
  );
  doc.addPage(b.cover());
  final body = [
    for (final s in ReportSection.values)
      if (sections.contains(s)) ...b.section(s),
  ];
  if (body.isNotEmpty) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 28, 40, 28),
      header: b.header,
      footer: b.footer,
      build: (_) => body,
    ));
  }
  return doc.save();
}

/// Логотип Scinode: сеть узлов на фирменном градиенте (как иконка приложения).
pw.Widget scinodeLogo(double size) {
  const pts = [
    (512.0, 512.0),
    (330.0, 380.0),
    (700.0, 340.0),
    (690.0, 690.0),
    (350.0, 690.0)
  ];
  const rad = [100.0, 62.0, 56.0, 66.0, 52.0];
  const cols = [
    PdfColors.white,
    PdfColor.fromInt(0xFF22D3EE),
    PdfColor.fromInt(0xFFA78BFA),
    PdfColor.fromInt(0xFF34D399),
    PdfColor.fromInt(0xFFFBBF24),
  ];
  const edges = [
    (0, 1),
    (0, 2),
    (0, 3),
    (0, 4),
    (1, 2),
    (2, 3),
    (3, 4),
    (4, 1)
  ];
  return pw.Container(
    width: size,
    height: size,
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(size * 230 / 1024),
      gradient: const pw.LinearGradient(
        begin: pw.Alignment.topCenter,
        end: pw.Alignment.bottomCenter,
        colors: [Brand.primaryDark, Brand.navy],
      ),
    ),
    child: pw.CustomPaint(
      size: PdfPoint(size, size),
      painter: (canvas, s) {
        final k = s.x / 1024;
        // В PDF ось y направлена вверх.
        double x(int i) => pts[i].$1 * k;
        double y(int i) => s.y - pts[i].$2 * k;
        canvas.setLineCap(PdfLineCap.round);
        for (final e in edges) {
          final main = e.$1 == 0;
          canvas
            ..saveContext()
            ..setGraphicState(
                PdfGraphicState(strokeOpacity: main ? 0.78 : 0.43))
            ..setStrokeColor(PdfColors.white)
            ..setLineWidth((main ? 16 : 10) * k)
            ..drawLine(x(e.$1), y(e.$1), x(e.$2), y(e.$2))
            ..strokePath()
            ..restoreContext();
        }
        for (var i = 0; i < pts.length; i++) {
          canvas
            ..setFillColor(cols[i])
            ..drawEllipse(x(i), y(i), rad[i] * k, rad[i] * k)
            ..fillPath();
        }
      },
    ),
  );
}

/// Кольцо прогресса (доля [v] от 0 до 1).
pw.Widget progressRing(double v, double size, String label,
    {PdfColor color = Brand.primary}) {
  return pw.SizedBox(
    width: size,
    height: size,
    child: pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        pw.CustomPaint(
          size: PdfPoint(size, size),
          painter: (canvas, s) {
            final c = PdfPoint(s.x / 2, s.y / 2);
            final w = s.x * 0.11;
            final rr = s.x / 2 - w / 2;
            canvas
              ..setStrokeColor(Brand.soft)
              ..setLineWidth(w)
              ..drawEllipse(c.x, c.y, rr, rr)
              ..strokePath();
            final f = v.clamp(0.0, 1.0);
            if (f <= 0) return;
            // Дуга по часовой стрелке от «12 часов» ломаной из мелких отрезков.
            final steps = max(2, (f * 120).round());
            canvas
              ..setStrokeColor(color)
              ..setLineCap(PdfLineCap.round)
              ..setLineWidth(w);
            for (var i = 0; i <= steps; i++) {
              final a = pi / 2 - 2 * pi * f * i / steps;
              final px = c.x + rr * cos(a), py = c.y + rr * sin(a);
              if (i == 0) {
                canvas.moveTo(px, py);
              } else {
                canvas.lineTo(px, py);
              }
            }
            canvas.strokePath();
          },
        ),
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: size * 0.22, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

class _Builder {
  _Builder(this.r, this.names, this.lang);
  final BoardReport r;
  final Map<String, String> names;
  final String lang;

  String date(DateTime d) => formatDate(d, lang);
  String period() => t(
      'rp.period_range', {'a': date(r.range.from), 'b': date(r.range.lastDay)});
  String name(String uid) => uid.isEmpty
      ? t('bd.f.nobody')
      : (names[uid]?.isNotEmpty == true ? names[uid]! : t('bd.unknown_user'));
  String people(List<String> uids) =>
      uids.isEmpty ? '—' : uids.map(name).join(', ');
  String colName(String id) => r.board.column(id)?.name ?? '—';
  String focus(int sec) {
    final (h, m) = hoursMinutes(sec);
    return h == 0 ? t('fo.min', {'m': m}) : t('fo.hmin', {'h': h, 'm': m});
  }

  // ------------------------------------------------------------ обложка

  pw.Page cover() {
    final members = [for (final m in r.board.members) name(m)];
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Фирменная шапка.
          pw.Container(
            height: 270,
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
                scinodeLogo(108),
                pw.SizedBox(height: 16),
                pw.Text('Scinode',
                    style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.5)),
                pw.SizedBox(height: 4),
                pw.Text(t('rp.pdf.tagline'),
                    style: const pw.TextStyle(
                        fontSize: 12, color: PdfColor.fromInt(0xFFD9D5FF))),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(56, 44, 56, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(t('rp.pdf.kind'),
                      style: pw.TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: Brand.primary,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(r.board.name,
                      maxLines: 3,
                      style: pw.TextStyle(
                          fontSize: 28, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 16),
                  pw.Container(width: 64, height: 4, color: Brand.primary),
                  pw.SizedBox(height: 22),
                  _info(t('rp.pdf.period'), period()),
                  _info(t('rp.pdf.members'), members.join(', ')),
                  _info(t('rp.pdf.generated'), date(r.generated)),
                  pw.SizedBox(height: 26),
                  _kpis(),
                ],
              ),
            ),
          ),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 16),
            color: Brand.soft,
            child: pw.Row(
              children: [
                scinodeLogo(18),
                pw.SizedBox(width: 8),
                pw.Text(t('rp.pdf.made_in'),
                    style: const pw.TextStyle(fontSize: 9, color: Brand.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _info(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
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

  pw.Widget _kpis() {
    pw.Widget tile(String label, String value, PdfColor c) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: Brand.soft,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 18,
                  height: 3,
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  decoration: pw.BoxDecoration(
                      color: c, borderRadius: pw.BorderRadius.circular(2)),
                ),
                pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: c)),
                pw.SizedBox(height: 2),
                pw.Text(label,
                    style: const pw.TextStyle(fontSize: 9, color: Brand.muted)),
              ],
            ),
          ),
        );
    return pw.Row(children: [
      tile(t('rp.done'), '${r.done}', Brand.done),
      tile(t('rp.open'), '${r.open}', Brand.open),
      tile(t('rp.overdue'), '${r.overdue}', Brand.late),
      tile(t('rp.pdf.progress'), '${r.percent}%', Brand.primary),
    ]);
  }

  // ------------------------------------------------ колонтитулы страниц

  pw.Widget header(pw.Context c) => pw.Container(
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
            pw.Spacer(),
            pw.Flexible(
              child: pw.Text('${r.board.name} · ${period()}',
                  maxLines: 1,
                  style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
            ),
          ],
        ),
      );

  pw.Widget footer(pw.Context c) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          children: [
            pw.Text('Scinode',
                style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
            pw.Spacer(),
            pw.Text(t('rp.pdf.page', {'p': c.pageNumber, 'n': c.pagesCount}),
                style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
          ],
        ),
      );

  // ------------------------------------------------------------ разделы

  pw.Widget _h1(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 10),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 16, color: Brand.primary),
          pw.SizedBox(width: 8),
          pw.Text(s,
              style:
                  pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        ]),
      );

  pw.Widget _h2(String s, {String? trailing}) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Row(children: [
          pw.Text(s,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (trailing != null) ...[
            pw.SizedBox(width: 6),
            pw.Text(trailing,
                style: const pw.TextStyle(fontSize: 10, color: Brand.muted)),
          ],
        ]),
      );

  pw.Widget _none([String? s]) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(s ?? t('rp.pdf.none'),
            style: const pw.TextStyle(color: Brand.muted)),
      );

  pw.Widget _table(List<String> head, List<List<String>> rows,
      {Map<int, pw.TableColumnWidth>? widths}) {
    return pw.TableHelper.fromTextArray(
      headers: head,
      data: rows,
      columnWidths: widths,
      border: null,
      headerStyle: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: Brand.primary),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      oddRowDecoration: const pw.BoxDecoration(color: Brand.soft),
      rowDecoration: const pw.BoxDecoration(
          border:
              pw.Border(bottom: pw.BorderSide(color: Brand.line, width: .5))),
    );
  }

  /// Горизонтальные полоски «подпись — полоска — число».
  pw.Widget _bars(List<(String, int, PdfColor)> rows,
      {String Function(int v)? fmt}) {
    final top = rows.fold(0, (a, x) => max(a, x.$2));
    const w = 260.0;
    return pw.Column(children: [
      for (final (label, v, c) in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 150,
                child: pw.Text(label,
                    maxLines: 1, style: const pw.TextStyle(fontSize: 9))),
            pw.Container(
              width: w,
              height: 10,
              alignment: pw.Alignment.centerLeft,
              decoration: pw.BoxDecoration(
                  color: Brand.soft, borderRadius: pw.BorderRadius.circular(5)),
              child: v == 0
                  ? null
                  : pw.Container(
                      width: max(6, w * v / max(1, top)),
                      height: 10,
                      decoration: pw.BoxDecoration(
                          color: c, borderRadius: pw.BorderRadius.circular(5)),
                    ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(fmt == null ? '$v' : fmt(v),
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
    ]);
  }

  List<pw.Widget> section(ReportSection s) => switch (s) {
        ReportSection.summary => _summary(),
        ReportSection.columns => _columns(),
        ReportSection.members => _members(),
        ReportSection.completed => _completed(),
        ReportSection.overdue => _overdue(),
        ReportSection.links => _links(),
        ReportSection.focus => _focus(),
      };

  List<pw.Widget> _summary() {
    final weeks = r.weekly;
    final top = max(1, weeks.fold(0, max));
    return [
      _h1(t('rp.sec.summary')),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          progressRing(
              r.total == 0 ? 0 : r.done / r.total, 96, '${r.percent}%'),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(t('rp.total', {'n': r.total}),
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text(t('rp.pdf.in_period',
                    {'d': r.doneInPeriod, 'c': r.createdInPeriod})),
                pw.SizedBox(height: 10),
                _kpis(),
              ],
            ),
          ),
        ],
      ),
      _h2(t('rp.weekly')),
      pw.SizedBox(
        height: 90,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < weeks.length; i++)
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('${weeks[i]}',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      width: 34,
                      height: max(2, 56.0 * weeks[i] / top),
                      decoration: pw.BoxDecoration(
                        color: i == weeks.length - 1
                            ? Brand.primary
                            : const PdfColor.fromInt(0xFFB7AEFF),
                        borderRadius: const pw.BorderRadius.vertical(
                            top: pw.Radius.circular(4)),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                        i == weeks.length - 1
                            ? t('rp.this_week')
                            : t('rp.weeks_ago', {'n': weeks.length - 1 - i}),
                        style: const pw.TextStyle(
                            fontSize: 8, color: Brand.muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
    ];
  }

  List<String> _taskRow(TaskCard c) => [
        c.title,
        c.due == null ? '—' : date(c.due!),
        people(c.assignees),
        t('bd.p.${c.priority}'),
      ];

  List<pw.Widget> _columns() {
    final widths = {
      0: const pw.FlexColumnWidth(4),
      1: const pw.FlexColumnWidth(1.3),
      2: const pw.FlexColumnWidth(2.2),
      3: const pw.FlexColumnWidth(1.3),
    };
    return [
      _h1(t('rp.sec.columns')),
      _bars([
        for (final c in r.columns)
          (
            c.column.name,
            c.cards.length,
            c.column.done ? Brand.done : Brand.primary
          ),
      ]),
      for (final c in r.columns) ...[
        _h2(c.column.name, trailing: '(${c.cards.length})'),
        if (c.cards.isEmpty)
          _none(t('rp.pdf.no_tasks'))
        else
          _table([
            t('rp.pdf.task'),
            t('rp.pdf.due'),
            t('rp.pdf.assignees'),
            t('rp.pdf.priority'),
          ], [
            for (final x in c.cards) _taskRow(x)
          ], widths: widths),
      ],
      pw.SizedBox(height: 10),
    ];
  }

  List<pw.Widget> _members() => [
        _h1(t('rp.sec.members')),
        if (r.members.isEmpty)
          _none()
        else ...[
          _bars([
            for (final m in r.members) (name(m.uid), m.open, Brand.open),
          ]),
          pw.SizedBox(height: 6),
          _table([
            t('rp.pdf.member'),
            t('rp.open'),
            t('rp.done'),
            t('rp.pdf.in_period_col'),
            t('rp.overdue'),
            t('rp.pdf.focus'),
          ], [
            for (final m in r.members)
              [
                name(m.uid),
                '${m.open}',
                '${m.done}',
                '${m.doneInPeriod}',
                '${m.overdue}',
                m.uid.isEmpty ? '—' : focus(m.focus),
              ],
          ], widths: {
            0: const pw.FlexColumnWidth(2.6),
            1: const pw.FlexColumnWidth(1.3),
            2: const pw.FlexColumnWidth(1.3),
            3: const pw.FlexColumnWidth(1.3),
            4: const pw.FlexColumnWidth(1.4),
            5: const pw.FlexColumnWidth(1.5),
          }),
        ],
        pw.SizedBox(height: 10),
      ];

  List<pw.Widget> _completed() => [
        _h1(t('rp.sec.completed')),
        pw.Text(period(), style: const pw.TextStyle(color: Brand.muted)),
        pw.SizedBox(height: 6),
        if (r.completed.isEmpty)
          _none()
        else
          _table([
            t('rp.pdf.task'),
            t('rp.pdf.done_at'),
            t('rp.pdf.assignees'),
          ], [
            for (final c in r.completed)
              [c.title, date(c.doneAt!), people(c.assignees)],
          ], widths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.4),
            2: const pw.FlexColumnWidth(2.2),
          }),
        pw.SizedBox(height: 10),
      ];

  List<pw.Widget> _overdue() => [
        _h1(t('rp.sec.overdue')),
        if (r.overdueCards.isEmpty)
          _none(t('rp.no_overdue'))
        else
          _table([
            t('rp.pdf.task'),
            t('rp.pdf.due'),
            t('rp.pdf.late_by'),
            t('rp.pdf.assignees'),
          ], [
            for (final c in r.overdueCards)
              [
                c.title,
                date(c.due!),
                t('rp.pdf.days', {
                  'n': dayOf(r.generated).difference(dayOf(c.due!)).inDays,
                }),
                people(c.assignees),
              ],
          ], widths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.3),
            2: const pw.FlexColumnWidth(1.3),
            3: const pw.FlexColumnWidth(2.2),
          }),
        pw.SizedBox(height: 10),
      ];

  List<pw.Widget> _links() => [
        _h1(t('rp.sec.links')),
        _h2(t('rp.pdf.papers'), trailing: '(${r.papers.length})'),
        if (r.papers.isEmpty)
          _none()
        else
          _table([
            t('rp.pdf.papers'),
            'DOI',
            t('rp.pdf.cards'),
          ], [
            for (final p in r.papers)
              [p.paper.title, p.paper.doi ?? '—', p.cards.join('; ')],
          ], widths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2.4),
          }),
        _h2(t('rp.pdf.grants'), trailing: '(${r.grants.length})'),
        if (r.grants.isEmpty)
          _none()
        else
          _table([
            t('rp.pdf.grants'),
            t('rp.pdf.number'),
            t('rp.pdf.deadline'),
            t('rp.pdf.cards'),
          ], [
            for (final g in r.grants)
              [
                g.grant.title,
                g.grant.number.isEmpty ? '—' : g.grant.number,
                g.grant.deadline == null ? '—' : date(g.grant.deadline!),
                g.cards.join('; '),
              ],
          ], widths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.6),
            2: const pw.FlexColumnWidth(1.3),
            3: const pw.FlexColumnWidth(2.2),
          }),
        pw.SizedBox(height: 10),
      ];

  List<pw.Widget> _focus() {
    final people = [
      for (final m in r.members)
        if (m.uid.isNotEmpty && m.focus > 0) m,
    ];
    return [
      _h1(t('rp.sec.focus')),
      pw.Text(t('rp.pdf.focus_total', {'t': focus(r.focusTotal)}),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(t('rp.pdf.focus_note'),
          style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
      pw.SizedBox(height: 8),
      if (r.focusCards.isEmpty)
        _none()
      else ...[
        if (people.isNotEmpty)
          _bars([
            for (final m in people) (name(m.uid), m.focus, Brand.primary),
          ], fmt: focus),
        pw.SizedBox(height: 6),
        _table([
          t('rp.pdf.task'),
          t('rp.pdf.focus'),
        ], [
          for (final f in r.focusCards) [f.card.title, focus(f.seconds)],
        ], widths: {
          0: const pw.FlexColumnWidth(5),
          1: const pw.FlexColumnWidth(1.4),
        }),
      ],
    ];
  }
}
