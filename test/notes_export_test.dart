import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/formula_templates.dart';
import 'package:scinode/models/note.dart';
import 'package:scinode/services/note_export.dart';
import 'package:scinode/services/report_pdf.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/strings_notes.dart';
import 'package:scinode/widgets/formula_sheet.dart';
import 'package:scinode/widgets/math_markdown.dart';

/// Настоящий PNG 1×1 (прозрачный).
final png1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

const body = '''# Вывод

Энергия: \$E = mc^2\$, а **импульс** — \$p = mv\$. Цена \$5 и \$10.

\$\$
\\int_0^1 x^2\\,dx = \\frac{1}{3}
\$\$

- первый пункт с \$\\alpha_i\$
- второй: 100% & #1_a {скобки}

1. раз
2. два

> цитата с _курсивом_

Узбекский: Oʻzbekiston, gʻoya. Ссылка: [DOI](https://doi.org/10.1/x).
''';

const paper = NotePaper(
    id: 'W1', title: 'Статья о 50% & #1', doi: '10.1038/nature14539', page: 7);

void main() {
  setUp(() => Strings.instance.lang = 'ru');

  group('LaTeX (.tex)', () {
    test('экранирование и структура', () {
      final tex = noteToLatex(
          title: 'Заметка_1 & {x}',
          body: body,
          paper: paper,
          date: DateTime(2026, 11, 5),
          lang: 'ru');
      expect(tex, contains(r'\documentclass[11pt]{article}'));
      expect(tex, contains(r'\usepackage[english,russian]{babel}'));
      expect(tex, contains(r'\title{Заметка\_1 \& \{x\}}'));
      expect(tex, contains(r'\section*{Вывод}'));
      expect(tex, contains(r'$E = mc^2$'));
      expect(tex, contains(r'\textbf{импульс}'));
      expect(tex, contains('Цена \\\$5 и \\\$10.'));
      expect(tex, contains('\\[\n\\int_0^1 x^2\\,dx = \\frac{1}{3}\n\\]'));
      expect(tex, contains(r'\begin{itemize}'));
      expect(tex, contains(r'100\% \& \#1\_a \{скобки\}'));
      expect(tex, contains(r'\begin{enumerate}'));
      expect(tex, contains(r'\begin{quote}'));
      expect(tex, contains(r'\emph{курсивом}'));
      expect(tex, contains('O‘zbekiston'));
      expect(tex, contains(r'\href{https://doi.org/10.1/x}{DOI}'));
      expect(tex, contains(r'\url{https://doi.org/10.1038/nature14539}'));
      expect(tex.trim(), endsWith(r'\end{document}'));
      // Для ручной проверки компиляцией: TEX_OUT=/путь flutter test ...
      final out = Platform.environment['TEX_OUT'];
      if (out != null) File('$out/note.tex').writeAsStringSync(tex);
    });

    test('английский интерфейс — английский основной язык', () {
      final tex = noteToLatex(
          title: 'Note', body: 'x', date: DateTime(2026), lang: 'en');
      expect(tex, contains(r'\usepackage[russian,english]{babel}'));
    });

    test('texEscape', () {
      expect(texEscape(r'a\b~c^d'),
          r'a\textbackslash{}b\textasciitilde{}c\textasciicircum{}d');
    });
  });

  test('Markdown (.md)', () {
    final md = noteToMarkdown(title: '', body: '# Вывод\nтекст', paper: paper);
    expect(md, startsWith('# Вывод\n\n> Статья о 50% & #1, стр. 7'));
    expect(md, contains('https://doi.org/10.1038/nature14539'));
    expect(md.trim(), endsWith('текст'));
  });

  test('имя файла', () {
    expect(noteFileName(r'Вывод: E=mc^2 / $', DateTime(2026, 11, 5), 'tex'),
        'Scinode_Вывод_E=mc^2_2026-11-05.tex');
    expect(noteFileName('', DateTime(2026, 1, 2), 'pdf'),
        'Scinode_2026-01-02.pdf');
  });

  test('размер PNG из заголовка', () {
    expect(pngSize(png1), (1, 1));
    expect(pngSize(Uint8List.fromList([1, 2, 3])), isNull);
  });

  group('PDF заметки', () {
    late ReportFonts fonts;
    setUpAll(() {
      ByteData read(String f) =>
          ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync());
      fonts = ReportFonts.fromBytes(
          read('NotoSans-Regular.ttf'), read('NotoSans-Bold.ttf'));
    });

    test('собирается, все формулы отданы на отрисовку', () async {
      final asked = <String>[];
      final bytes = await buildNotePdf(
        title: 'Вывод',
        body: body,
        paper: paper,
        date: DateTime(2026, 11, 5),
        lang: 'ru',
        fonts: fonts,
        render: (tex, display) async {
          asked.add('$display:$tex');
          return MathImage(png1, display ? 80 : 30, display ? 24 : 10);
        },
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(asked, [
        'false:E = mc^2',
        'false:p = mv',
        r'true:\int_0^1 x^2\,dx = \frac{1}{3}',
        r'false:\alpha_i',
      ]);
    });

    test('если формулу не нарисовать — PDF всё равно собирается', () async {
      final bytes = await buildNotePdf(
        title: '',
        body: r'Ошибка $\frac{a}{$ и $$\sum$$',
        date: DateTime(2026),
        lang: 'en',
        fonts: fonts,
        render: (_, __) async => null,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('Шаблоны формул', () {
    test('все шаблоны — правильный LaTeX, у каждого есть название', () {
      final keys = <String>{};
      for (final f in formulaTemplates) {
        expect(texError(f.tex), isNull, reason: f.key);
        expect(noteStrings['ft.${f.key}'], isNotNull, reason: f.key);
        expect(keys.add(f.key), isTrue, reason: 'повтор ${f.key}');
      }
      for (final c in FormulaCategory.values) {
        expect(noteStrings['ft.cat.${c.name}'], isNotNull);
        expect(formulaTemplates.where((f) => f.category == c).length,
            greaterThanOrEqualTo(6));
      }
    });

    test('мои формулы: без повторов, частые и свежие первыми', () {
      expect(myFormulas(['a', 'b', 'c', 'b', ' ', 'c', 'c', 'd']),
          ['c', 'b', 'a', 'd']);
      expect(myFormulas(List.generate(100, (i) => 'x$i')).length, 40);
    });

    test('вставка шаблона: блоком вне формулы, как есть внутри', () {
      final c = TextEditingController(text: 'Итак');
      c.selection = const TextSelection.collapsed(offset: 4);
      insertFormula(c, 'E=mc^2');
      expect(c.text, 'Итак\n\$\$\nE=mc^2\n\$\$\n');
      expect(c.selection.baseOffset, c.text.length);

      final d = TextEditingController(text: r'$x + $');
      d.selection = const TextSelection.collapsed(offset: 5);
      insertFormula(d, r'\pi');
      expect(d.text, r'$x + \pi$');
    });
  });

  group('Формулы в чате и комментариях', () {
    Future<void> pump(WidgetTester tester, String text) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: MathText(text))));

    testWidgets('формула рисуется, звёздочки и деньги — нет', (tester) async {
      await pump(tester, r'Посмотри: $\frac{a}{b}$ и *не курсив*');
      expect(find.byType(Math), findsOneWidget);
      expect(find.textContaining('*не курсив*', findRichText: true),
          findsOneWidget);
      await pump(tester, r'Pro за $5 и $10');
      expect(find.byType(Math), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
    });
  });
}
