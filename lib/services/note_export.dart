import 'dart:typed_data';

import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/grant.dart' show formatDate;
import '../models/note.dart';
import '../strings.dart';
import '../widgets/math_markdown.dart' show MathMarkdown;
import 'report_pdf.dart';

/// Разбор текста заметки тем же разбором, что и на экране.
List<md.Node> parseNote(String body) =>
    md.Document(extensionSet: MathMarkdown.extensions, encodeHtml: false)
        .parseLines(body.replaceAll('\r\n', '\n').split('\n'));

String _name(String title, String body) {
  final n = Note(id: '', owner: '', title: title, body: body).displayTitle;
  return n.isEmpty ? t('nt.untitled') : n;
}

/// Имя файла: «Scinode_Заголовок_2026-11-05.ext».
String noteFileName(String title, DateTime d, String ext) {
  final clean = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\s$]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final short = clean.length > 40 ? clean.substring(0, 40) : clean;
  String two(int x) => x.toString().padLeft(2, '0');
  final date = '${d.year}-${two(d.month)}-${two(d.day)}';
  return short.isEmpty ? 'Scinode_$date.$ext' : 'Scinode_${short}_$date.$ext';
}

// ============================================================ Markdown (.md)

String noteToMarkdown(
    {required String title, required String body, NotePaper? paper}) {
  final b = StringBuffer('# ${_name(title, body)}\n\n');
  if (paper != null) {
    b.write('> ${paper.title}');
    if (paper.page != null) b.write(', ${t('nt.page', {'p': paper.page!})}');
    if (paper.doi != null) b.write(' — https://doi.org/${paper.doi}');
    b.write('\n\n');
  }
  b.write(body.trim());
  b.write('\n');
  return b.toString();
}

// ============================================================ LaTeX (.tex)

/// Экранирование обычного текста для LaTeX.
String texEscape(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    b.write(switch (c) {
      r'\' => r'\textbackslash{}',
      '{' || '}' || r'$' || '&' || '#' || '%' || '_' => '\\$c',
      '~' => r'\textasciitilde{}',
      '^' => r'\textasciicircum{}',
      // Узбекские oʻ/gʻ: в pdfLaTeX надёжнее обычный апостроф-кавычка.
      'ʻ' || 'ʼ' => '‘',
      _ => c,
    });
  }
  return b.toString();
}

/// Заметка в виде документа LaTeX, который собирается в Overleaf
/// (pdfLaTeX, кириллица и латиница) без правок.
String noteToLatex(
    {required String title,
    required String body,
    NotePaper? paper,
    required DateTime date,
    required String lang}) {
  final out = StringBuffer()
    ..writeln('% ${t('nt.tex_made')}')
    ..writeln(r'\documentclass[11pt]{article}')
    ..writeln(r'\usepackage[utf8]{inputenc}')
    ..writeln(r'\usepackage[T2A,T1]{fontenc}')
    ..writeln(lang == 'ru'
        ? r'\usepackage[english,russian]{babel}'
        : r'\usepackage[russian,english]{babel}')
    ..writeln(r'\usepackage{amsmath,amssymb}')
    ..writeln(r'\usepackage[margin=2.5cm]{geometry}')
    ..writeln(r'\usepackage{hyperref}')
    ..writeln()
    ..writeln('\\title{${texEscape(_name(title, body))}}')
    ..writeln('\\date{${formatDate(date, lang)}}')
    ..writeln(r'\author{}')
    ..writeln()
    ..writeln(r'\begin{document}')
    ..writeln(r'\maketitle')
    ..writeln();
  if (paper != null) {
    out.write('\\noindent\\textit{${texEscape(paper.title)}');
    if (paper.page != null) {
      out.write(', ${texEscape(t('nt.page', {'p': paper.page!}))}');
    }
    out.write('}');
    if (paper.doi != null) {
      out.write(' --- \\url{https://doi.org/${paper.doi}}');
    }
    out.writeln('\n');
  }
  out
    ..write(_Tex().blocks(parseNote(body)))
    ..writeln(r'\end{document}');
  return out.toString();
}

class _Tex {
  String blocks(List<md.Node> nodes) =>
      [for (final n in nodes) block(n)].where((s) => s.isNotEmpty).join('\n');

  String block(md.Node n) {
    if (n is md.Text) return '${inline([n])}\n';
    if (n is! md.Element) return '';
    final kids = n.children ?? const <md.Node>[];
    switch (n.tag) {
      case 'h1':
        return '\\section*{${inline(kids)}}\n';
      case 'h2':
        return '\\subsection*{${inline(kids)}}\n';
      case 'h3' || 'h4' || 'h5' || 'h6':
        return '\\subsubsection*{${inline(kids)}}\n';
      case 'p':
        return '${inline(kids)}\n';
      case 'ul' || 'ol':
        final env = n.tag == 'ul' ? 'itemize' : 'enumerate';
        final items = [
          for (final li in kids)
            if (li is md.Element && li.tag == 'li')
              '  \\item ${_li(li).trim()}',
        ];
        return '\\begin{$env}\n${items.join('\n')}\n\\end{$env}\n';
      case 'blockquote':
        return '\\begin{quote}\n${blocks(kids)}\\end{quote}\n';
      case 'pre':
        return '\\begin{verbatim}\n${n.textContent.trimRight()}\n\\end{verbatim}\n';
      case 'hr':
        return '\\noindent\\rule{\\linewidth}{0.4pt}\n';
      case 'latex':
        return _math(n);
      default:
        return '${inline(kids)}\n';
    }
  }

  String _li(md.Element li) {
    final kids = li.children ?? const <md.Node>[];
    // Пункт может быть «тесным» (текст) или содержать абзацы и списки.
    if (kids.every((k) => k is md.Text || _isInline(k))) return inline(kids);
    return blocks(kids);
  }

  bool _isInline(md.Node n) =>
      n is md.Element &&
      const {'strong', 'em', 'code', 'a', 'latex', 'del', 'br', 'img'}
          .contains(n.tag);

  String _math(md.Element e) {
    final tex = e.textContent.trim();
    return e.attributes['MathStyle'] == 'display'
        ? '\n\\[\n$tex\n\\]\n'
        : '\$$tex\$';
  }

  String inline(List<md.Node> nodes) {
    final b = StringBuffer();
    for (final n in nodes) {
      if (n is md.Text) {
        b.write(texEscape(n.text));
      } else if (n is md.Element) {
        final kids = n.children ?? const <md.Node>[];
        b.write(switch (n.tag) {
          'strong' => '\\textbf{${inline(kids)}}',
          'em' => '\\emph{${inline(kids)}}',
          'del' => inline(kids),
          'code' => '\\texttt{${texEscape(n.textContent)}}',
          'a' => n.attributes['href'] != null
              ? '\\href{${n.attributes['href']!.replaceAll('%', r'\%').replaceAll('#', r'\#')}}{${inline(kids)}}'
              : inline(kids),
          'br' => '\\\\\n',
          'latex' => _math(n),
          _ => inline(kids),
        });
      }
    }
    return b.toString();
  }
}

// ================================================================== PDF

/// Картинка формулы для PDF: PNG и её размер в точках.
class MathImage {
  const MathImage(this.png, this.width, this.height);
  final Uint8List png;
  final double width;
  final double height;
}

/// Рисует формулу [tex] в картинку (в приложении — через Flutter).
typedef MathRenderer = Future<MathImage?> Function(String tex, bool display);

/// PDF заметки с фирменным оформлением Scinode; формулы — картинками.
Future<Uint8List> buildNotePdf({
  required String title,
  required String body,
  NotePaper? paper,
  required DateTime date,
  required String lang,
  required ReportFonts fonts,
  required MathRenderer render,
}) async {
  final nodes = parseNote(body);
  // Сначала рисуем все формулы (асинхронно), потом собираем страницы.
  final images = <md.Element, MathImage?>{};
  Future<void> collect(List<md.Node> list) async {
    for (final n in list) {
      if (n is! md.Element) continue;
      if (n.tag == 'latex') {
        images[n] = await render(
            n.textContent.trim(), n.attributes['MathStyle'] == 'display');
      } else {
        await collect(n.children ?? const []);
      }
    }
  }

  await collect(nodes);
  final b = _Pdf(images, fonts);
  final name = _name(title, body);
  final doc = pw.Document(title: name, author: 'Scinode', creator: 'Scinode');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(48, 32, 48, 32),
    theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold)
        .copyWith(
            defaultTextStyle: pw.TextStyle(
                font: fonts.regular,
                fontBold: fonts.bold,
                fontSize: 11,
                lineSpacing: 2,
                color: Brand.ink)),
    header: (c) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: Brand.line))),
      child: pw.Row(children: [
        scinodeLogo(14),
        pw.SizedBox(width: 6),
        pw.Text('Scinode',
            style: pw.TextStyle(
                fontSize: 9,
                color: Brand.primary,
                fontWeight: pw.FontWeight.bold)),
        pw.Spacer(),
        pw.Text(t('nt.pdf_kind'),
            style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
      ]),
    ),
    footer: (c) => pw.Row(children: [
      pw.Text(t('rp.pdf.made_in'),
          style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
      pw.Spacer(),
      pw.Text(t('rp.pdf.page', {'p': c.pageNumber, 'n': c.pagesCount}),
          style: const pw.TextStyle(fontSize: 8, color: Brand.muted)),
    ]),
    build: (_) => [
      pw.Text(name,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text(formatDate(date, lang),
          style: const pw.TextStyle(fontSize: 9, color: Brand.muted)),
      if (paper != null) ...[
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
              color: Brand.soft, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Text(
            [
              paper.title,
              if (paper.page != null) t('nt.page', {'p': paper.page!}),
              if (paper.doi != null) 'DOI ${paper.doi}',
            ].join(' · '),
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
      pw.SizedBox(height: 10),
      pw.Container(width: 48, height: 3, color: Brand.primary),
      pw.SizedBox(height: 12),
      ...b.blocks(nodes),
    ],
  ));
  return doc.save();
}

class _Pdf {
  _Pdf(this.images, this.fonts);
  final Map<md.Element, MathImage?> images;
  final ReportFonts fonts;

  List<pw.Widget> blocks(List<md.Node> nodes) =>
      [for (final n in nodes) ...block(n)];

  List<pw.Widget> block(md.Node n) {
    if (n is md.Text)
      return [
        _para([n])
      ];
    if (n is! md.Element) return const [];
    final kids = n.children ?? const <md.Node>[];
    switch (n.tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final size = switch (n.tag) { 'h1' => 17.0, 'h2' => 14.5, _ => 12.5 };
        return [
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.RichText(
                text: pw.TextSpan(
                    style: pw.TextStyle(
                        fontSize: size, fontWeight: pw.FontWeight.bold),
                    children: spans(kids))),
          )
        ];
      case 'p':
        // Абзац из одной формулы-блока — по центру.
        if (kids.length == 1 &&
            kids.first is md.Element &&
            (kids.first as md.Element).tag == 'latex' &&
            (kids.first as md.Element).attributes['MathStyle'] == 'display') {
          return [_display(kids.first as md.Element)];
        }
        return [_para(kids)];
      case 'latex':
        return [_display(n)];
      case 'ul' || 'ol':
        var i = 0;
        return [
          for (final li in kids)
            if (li is md.Element && li.tag == 'li')
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 16,
                      child: pw.Text(n.tag == 'ul' ? '•' : '${++i}.'),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: (li.children ?? const <md.Node>[])
                                .every((k) => k is md.Text || _inlineTag(k))
                            ? [_para(li.children!, bottom: 0)]
                            : blocks(li.children ?? const []),
                      ),
                    ),
                  ],
                ),
              ),
        ];
      case 'blockquote':
        return [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.only(left: 10),
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    left: pw.BorderSide(color: Brand.line, width: 3))),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: blocks(kids)),
          )
        ];
      case 'pre':
        return [
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            color: Brand.soft,
            child: pw.Text(n.textContent.trimRight(),
                style: const pw.TextStyle(fontSize: 9)),
          )
        ];
      case 'hr':
        return [pw.Divider(color: Brand.line)];
      default:
        return [_para(kids)];
    }
  }

  bool _inlineTag(md.Node n) =>
      n is md.Element &&
      const {'strong', 'em', 'code', 'a', 'latex', 'del', 'br'}.contains(n.tag);

  pw.Widget _para(List<md.Node> kids, {double bottom = 6}) => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: bottom),
        child: pw.RichText(text: pw.TextSpan(children: spans(kids))),
      );

  pw.Widget _display(md.Element e) {
    final img = images[e];
    if (img == null) return _texFallback(e.textContent);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Center(
        child: pw.Image(pw.MemoryImage(img.png),
            width: img.width, height: img.height),
      ),
    );
  }

  pw.Widget _texFallback(String tex) =>
      pw.Text(tex, style: const pw.TextStyle(fontSize: 9, color: Brand.late));

  List<pw.InlineSpan> spans(List<md.Node> nodes,
      {bool bold = false, bool italic = false}) {
    final out = <pw.InlineSpan>[];
    for (final n in nodes) {
      if (n is md.Text) {
        out.add(pw.TextSpan(
          text: n.text,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : null,
            // В шрифте нет курсива: курсив показываем цветом.
            color: italic ? Brand.primaryDark : null,
          ),
        ));
      } else if (n is md.Element) {
        final kids = n.children ?? const <md.Node>[];
        switch (n.tag) {
          case 'strong':
            out.addAll(spans(kids, bold: true, italic: italic));
          case 'em':
            out.addAll(spans(kids, bold: bold, italic: true));
          case 'code':
            out.add(pw.TextSpan(
                text: n.textContent,
                style: const pw.TextStyle(
                    background: pw.BoxDecoration(color: Brand.soft))));
          case 'br':
            out.add(const pw.TextSpan(text: '\n'));
          case 'latex':
            final img = images[n];
            out.add(img == null
                ? pw.TextSpan(
                    text: n.textContent,
                    style: const pw.TextStyle(color: Brand.late))
                : pw.WidgetSpan(
                    baseline: -img.height * 0.25,
                    child: pw.Image(pw.MemoryImage(img.png),
                        width: img.width, height: img.height),
                  ));
          default:
            out.addAll(spans(kids, bold: bold, italic: italic));
        }
      }
    }
    return out;
  }
}

/// Размер PNG (ширина, высота) из заголовка файла.
(int, int)? pngSize(Uint8List b) {
  if (b.length < 24 || b[0] != 0x89 || b[1] != 0x50) return null;
  int u32(int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (u32(16), u32(20));
}
