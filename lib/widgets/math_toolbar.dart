import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import '../strings.dart';
import 'math_markdown.dart';

/// Кнопка панели: как выглядит (формула или текст) и что вставляет.
class MathKey {
  const MathKey(this.label, this.snippet,
      {this.math = true, this.tex = true, this.tip});

  /// Подпись: формула LaTeX (если [tex]) или обычный текст.
  final String label;

  /// Что вставить; `¦` — место курсора.
  final String snippet;

  /// Вставка внутри формулы (вне формулы оборачивается в `$…$`).
  final bool math;
  final bool tex;

  /// Ключ подсказки (строка интерфейса) или null.
  final String? tip;
}

/// Набор кнопок: сначала оформление и формулы, затем частые символы.
const mathKeys = <MathKey>[
  MathKey(r'$x$', r'$¦$', math: false, tex: false, tip: 'nt.k.inline'),
  MathKey(r'$$', '\n\$\$\n¦\n\$\$\n',
      math: false, tex: false, tip: 'nt.k.block'),
  MathKey(r'\frac{a}{b}', r'\frac{¦}{}', tip: 'nt.k.frac'),
  MathKey(r'x^{n}', r'^{¦}', tip: 'nt.k.pow'),
  MathKey(r'x_{i}', r'_{¦}', tip: 'nt.k.sub'),
  MathKey(r'\sqrt{x}', r'\sqrt{¦}', tip: 'nt.k.sqrt'),
  MathKey(r'\sum', r'\sum_{¦}^{}', tip: 'nt.k.sum'),
  MathKey(r'\int', r'\int_{¦}^{}', tip: 'nt.k.int'),
  MathKey(r'\lim', r'\lim_{¦ \to }', tip: 'nt.k.lim'),
  MathKey(r'\partial', r'\partial ¦'),
  MathKey(r'\infty', r'\infty ¦'),
  MathKey(r'\pm', r'\pm ¦'),
  MathKey(r'\cdot', r'\cdot ¦'),
  MathKey(r'\times', r'\times ¦'),
  MathKey(r'\le', r'\le ¦'),
  MathKey(r'\ge', r'\ge ¦'),
  MathKey(r'\ne', r'\ne ¦'),
  MathKey(r'\approx', r'\approx ¦'),
  MathKey(r'\to', r'\to ¦'),
  MathKey(r'\vec{v}', r'\vec{¦}', tip: 'nt.k.vec'),
  MathKey(r'\bar{x}', r'\bar{¦}', tip: 'nt.k.bar'),
  MathKey(r'\hat{x}', r'\hat{¦}'),
  MathKey(r'(\,)', r'\left( ¦ \right)', tip: 'nt.k.paren'),
  MathKey(r'\begin{pmatrix}a&b\\c&d\end{pmatrix}',
      '\\begin{pmatrix} ¦ & \\\\  & \\end{pmatrix}',
      tip: 'nt.k.matrix'),
  MathKey(r'\alpha', r'\alpha ¦'),
  MathKey(r'\beta', r'\beta ¦'),
  MathKey(r'\gamma', r'\gamma ¦'),
  MathKey(r'\delta', r'\delta ¦'),
  MathKey(r'\varepsilon', r'\varepsilon ¦'),
  MathKey(r'\theta', r'\theta ¦'),
  MathKey(r'\lambda', r'\lambda ¦'),
  MathKey(r'\mu', r'\mu ¦'),
  MathKey(r'\pi', r'\pi ¦'),
  MathKey(r'\sigma', r'\sigma ¦'),
  MathKey(r'\varphi', r'\varphi ¦'),
  MathKey(r'\omega', r'\omega ¦'),
  MathKey(r'\Delta', r'\Delta ¦'),
  MathKey(r'\Sigma', r'\Sigma ¦'),
  MathKey(r'\Omega', r'\Omega ¦'),
  MathKey('B', '**¦**', math: false, tex: false, tip: 'nt.k.bold'),
  MathKey('H', '\n## ¦', math: false, tex: false, tip: 'nt.k.head'),
  MathKey('•', '\n- ¦', math: false, tex: false, tip: 'nt.k.list'),
];

/// Вставляет [k] в поле [c] (с учётом выделения и места курсора).
void applyMathKey(TextEditingController c, MathKey k) {
  final sel = c.selection;
  final start = sel.isValid ? sel.start : c.text.length;
  final end = sel.isValid ? sel.end : c.text.length;
  final e = insertSnippet(c.text, start, end, k.snippet, math: k.math);
  c.value = TextEditingValue(
    text: e.text,
    selection: TextSelection(baseOffset: e.selStart, extentOffset: e.selEnd),
  );
  HapticFeedback.selectionClick();
}

/// Полоса над клавиатурой: живой просмотр формулы под курсором и кнопки.
class MathToolbar extends StatelessWidget {
  const MathToolbar({super.key, required this.controller, this.onTemplates});
  final TextEditingController controller;

  /// Кнопка «Шаблоны формул» (null — не показывать).
  final VoidCallback? onTemplates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (ctx, v, _) => _LivePreview(value: v),
          ),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                if (onTemplates != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton.filledTonal(
                      tooltip: t('nt.templates'),
                      icon: const Icon(Icons.auto_awesome_mosaic_outlined),
                      onPressed: onTemplates,
                    ),
                  ),
                Expanded(
                    child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: mathKeys.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (_, i) {
                    final k = mathKeys[i];
                    final child = k.tex
                        ? MathView(k.label)
                        : Text(k.label,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800));
                    final btn = Material(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => applyMathKey(controller, k),
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(minWidth: 48, minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Center(
                              child: MediaQuery.withNoTextScaling(
                                  child: FittedBox(child: child)),
                            ),
                          ),
                        ),
                      ),
                    );
                    final tip = k.tip;
                    return tip == null
                        ? btn
                        : Tooltip(message: t(tip), child: btn);
                  },
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.value});
  final TextEditingValue value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = value.text;
    final pos = value.selection.isValid ? value.selection.start : text.length;
    final f = formulaAt(text, pos);
    Widget child;
    if (f == null) {
      child = Text(
        insideMath(text, pos) ? t('nt.unclosed') : t('nt.hint_math'),
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      );
    } else {
      final tex = f.texOf(text);
      final err = texError(tex);
      child = err == null
          ? MathView(tex)
          : Text(
              t('nt.formula_error', {'e': err}),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.error),
            );
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}
