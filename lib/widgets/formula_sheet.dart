import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/formula_templates.dart';
import '../models/note.dart';
import '../strings.dart';
import 'math_markdown.dart';

/// Вставляет готовую формулу [tex] в поле [c]: внутри формулы — как есть,
/// иначе — отдельным блоком `$$…$$`.
void insertFormula(TextEditingController c, String tex) {
  final sel = c.selection;
  final start = sel.isValid ? sel.start : c.text.length;
  final end = sel.isValid ? sel.end : c.text.length;
  final inside = insideMath(c.text, start);
  final before = c.text.substring(0, start.clamp(0, c.text.length));
  final lead = before.isEmpty || before.endsWith('\n') ? '' : '\n';
  final snippet = inside ? '$tex¦' : '$lead\$\$\n$tex\n\$\$\n¦';
  final e = insertSnippet(c.text, start, end, snippet, math: false);
  c.value = TextEditingValue(
    text: e.text,
    selection: TextSelection.collapsed(offset: e.selStart),
  );
  HapticFeedback.selectionClick();
}

/// Шаблоны формул и «Мои формулы» из заметок.
Future<void> showFormulaSheet(BuildContext context,
    {required TextEditingController controller, List<String> mine = const []}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.94,
      builder: (ctx, sc) =>
          _FormulaSheet(controller: controller, mine: mine, scroll: sc),
    ),
  );
}

class _FormulaSheet extends StatefulWidget {
  const _FormulaSheet(
      {required this.controller, required this.mine, required this.scroll});
  final TextEditingController controller;
  final List<String> mine;
  final ScrollController scroll;

  @override
  State<_FormulaSheet> createState() => _FormulaSheetState();
}

class _FormulaSheetState extends State<_FormulaSheet> {
  /// null — «Мои формулы».
  late FormulaCategory? _cat =
      widget.mine.isNotEmpty ? null : FormulaCategory.math;

  void _pick(String tex) {
    insertFormula(widget.controller, tex);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final items = _cat == null
        ? [for (final m in widget.mine) (null, m)]
        : [
            for (final f in formulaTemplates)
              if (f.category == _cat) (f.key, f.tex)
          ];
    return ListView(
      controller: widget.scroll,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      children: [
        Text(t('nt.templates'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.mine.isNotEmpty)
              ChoiceChip(
                label: Text(t('nt.mine')),
                selected: _cat == null,
                showCheckmark: false,
                onSelected: (_) => setState(() => _cat = null),
              ),
            for (final c in FormulaCategory.values)
              ChoiceChip(
                label: Text(t('ft.cat.${c.name}')),
                selected: _cat == c,
                showCheckmark: false,
                onSelected: (_) => setState(() => _cat = c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final (key, tex) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _pick(tex),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (key != null)
                        Text(t('ft.$key'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      MathView(tex, display: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
