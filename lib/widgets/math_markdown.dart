import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart' show TexParser;
import 'package:markdown/markdown.dart' as md;

import '../models/note.dart' show findFormulas;

/// Текст с Markdown и формулами LaTeX.
///
/// Формулы: `$…$` и `\(…\)` в строке, `$$…$$` и `\[…\]` отдельным блоком
/// (на одной строке или на нескольких: `$$` на своей строке, формула,
/// закрывающая `$$`). Знак доллара в обычном тексте (`$5 и $10`) формулой не
/// считается: после открывающего `$` не должно быть пробела, перед
/// закрывающим — пробела (кроме пробела после команды вроде `\alpha `),
/// а после закрывающего — цифры (как в Pandoc).
/// `\$` — просто знак доллара.
class MathMarkdown extends StatelessWidget {
  const MathMarkdown(this.data, {super.key, this.selectable = false});
  final String data;
  final bool selectable;

  static final md.ExtensionSet extensions = md.ExtensionSet(
    [MathBlockSyntax(), ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
    [MathInlineSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
  );

  @override
  Widget build(BuildContext context) => MarkdownBody(
        data: data,
        selectable: selectable,
        extensionSet: extensions,
        builders: {'latex': MathBuilder()},
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
      );
}

/// Формулы внутри строки.
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax() : super(_pattern);

  static const _pattern = r'\$\$([^\n]+?)\$\$' // $$…$$ в строке
      r'|(?<![\\$])\$(?![\s$])([^$\n]*?(?:[^\s\\$]|\\[A-Za-z]+ ))\$(?![\d$])' // $…$
      r'|(?<![\\$])\$([^\s\\$])\$(?![\d$])' // $x$
      r'|\\\((.+?)\\\)' // \(…\)
      r'|\\\[(.+?)\\\]'; // \[…\] в строке

  @override
  bool onMatch(md.InlineParser parser, Match m) {
    final display = m[1] != null || m[5] != null;
    final tex = (m[1] ?? m[2] ?? m[3] ?? m[4] ?? m[5] ?? '').trim();
    parser.addNode(md.Element.text('latex', tex)
      ..attributes['MathStyle'] = display ? 'display' : 'text');
    return true;
  }
}

/// Формула отдельным блоком на нескольких строках.
class MathBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*(\$\$|\\\[)\s*$');

  @override
  md.Node? parse(md.BlockParser parser) {
    final open = pattern.firstMatch(parser.current.content)![1]!;
    final close = open == r'$$' ? r'$$' : r'\]';
    parser.advance();
    final lines = <String>[];
    while (!parser.isDone && parser.current.content.trim() != close) {
      lines.add(parser.current.content);
      parser.advance();
    }
    if (!parser.isDone) parser.advance(); // закрывающая строка
    final el = md.Element.text('latex', lines.join('\n').trim())
      ..attributes['MathStyle'] = 'display';
    return md.Element('p', [el]);
  }
}

/// Рисует формулу (KaTeX на Dart, без интернета); ошибку показывает текстом.
class MathBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(BuildContext context, md.Element element,
      TextStyle? preferredStyle, TextStyle? parentStyle) {
    final tex = element.textContent;
    if (tex.isEmpty) return const SizedBox.shrink();
    final display = element.attributes['MathStyle'] == 'display';
    return MathView(tex, display: display, style: parentStyle);
  }
}

/// Одна формула с горизонтальной прокруткой, если не помещается.
class MathView extends StatelessWidget {
  const MathView(this.tex, {super.key, this.display = false, this.style});
  final String tex;
  final bool display;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final math = Math.tex(
      tex,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: (style ?? DefaultTextStyle.of(context).style)
          .copyWith(color: style?.color ?? scheme.onSurface),
      onErrorFallback: (e) => Text(
        tex,
        style: TextStyle(
          color: scheme.error,
          fontFamily: 'monospace',
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
        ),
      ),
    );
    final scroll = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: math,
    );
    if (!display) return scroll;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(child: scroll),
    );
  }
}

/// Обычный текст, в котором отрисованы только формулы (без Markdown):
/// для сообщений чата и комментариев, чтобы `*` и `_` не меняли текст.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final f = findFormulas(text);
    if (f.isEmpty) return SelectableText(text, style: style);
    final spans = <InlineSpan>[];
    var at = 0;
    for (final x in f) {
      if (x.start > at) spans.add(TextSpan(text: text.substring(at, x.start)));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: MathView(x.texOf(text), display: x.display, style: style),
      ));
      at = x.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

/// Ошибка в формуле [tex] или null, если формула правильная.
String? texError(String tex) {
  if (tex.trim().isEmpty) return null;
  try {
    TexParser(tex, const TexParserSettings()).parse();
    return null;
  } on ParseException catch (e) {
    return e.message;
  } catch (e) {
    return '$e';
  }
}
