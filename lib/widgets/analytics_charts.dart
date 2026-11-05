import 'dart:math';

import 'package:flutter/material.dart';

/// Цвета разделов Аналитики (видны в светлой и тёмной теме).
class AnColors {
  static Color article(ColorScheme s) => s.primary;
  static Color conference(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFD97706);
  static Color other(ColorScheme s) => s.outline;
  static const good = Color(0xFF10B981);

  /// Метка «страна» на полосках — оранжевая, чтобы не сливаться с полоской.
  static const country = Color(0xFFF97316);
}

/// Один столбик: части снизу вверх.
class StackPart {
  const StackPart(this.value, this.color);
  final int value;
  final Color color;
}

/// Столбики по годам; нажатие выбирает год (подпись снизу — в [footer]).
class YearBars extends StatelessWidget {
  const YearBars({
    super.key,
    required this.years,
    required this.parts,
    required this.selected,
    required this.onSelect,
    this.dimLast = false,
    this.height = 150,
  });

  final List<int> years;
  final List<List<StackPart>> parts;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Последний год неполный — рисуем его бледнее.
  final bool dimLast;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totals = [
      for (final p in parts) p.fold<int>(0, (a, b) => a + b.value)
    ];
    final top = max(1, totals.fold<int>(0, max));
    return Semantics(
      container: true,
      child: SizedBox(
        height: height + 28,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < years.length; i++)
              Expanded(
                child: InkWell(
                  key: Key('an.bar.${years[i]}'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Opacity(
                          opacity: dimLast && i == years.length - 1 ? 0.45 : 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5)),
                              border: i == selected
                                  ? Border.all(
                                      color: scheme.onSurface, width: 1.5)
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                              child: Column(
                                children: [
                                  for (final p in parts[i].reversed)
                                    Container(
                                      height: height * p.value / top,
                                      color: p.color,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (totals[i] == 0)
                          Container(height: 2, color: scheme.outlineVariant),
                        const SizedBox(height: 4),
                        YearLabel(years[i], bold: i == selected),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Подпись года под столбиком: «'25», всегда в одну строку.
class YearLabel extends StatelessWidget {
  const YearLabel(this.year, {super.key, this.bold = false});
  final int year;
  final bool bold;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 16,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "'${(year % 100).toString().padLeft(2, '0')}",
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
}

/// Цветная точка с подписью (легенда).
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
        ],
      );
}

/// Доля с полоской и метками «мир» и «страна».
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    this.scaleMax = 1,
    this.world,
    this.country,
    this.caption,
  });

  final String label;
  final String valueText;
  final double? value;

  /// Правый край полоски (например, 0.2 для топ-10 %, чтобы метки не слиплись).
  final double scaleMax;
  final double? world;
  final double? country;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    double f(double? v) => v == null ? 0 : (v / scaleMax).clamp(0.0, 1.0);
    final good = world != null && value != null && value! >= world!;
    final color = good ? AnColors.good : scheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(valueText,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              Widget mark(double? v, Color col) => v == null
                  ? const SizedBox.shrink()
                  : Positioned(
                      left: (w * f(v) - 1.5).clamp(0, w - 3),
                      top: -3,
                      child: Container(width: 3, height: 18, color: col),
                    );
              return SizedBox(
                height: 12,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: color.withAlpha(35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: f(value),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    mark(world, scheme.onSurfaceVariant),
                    mark(country, AnColors.country),
                  ],
                ),
              );
            },
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Строка «название — число» с полоской относительно [max].
class CountBar extends StatelessWidget {
  const CountBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.valueText,
    this.color,
    this.sub,
    this.trailing,
    this.onTap,
  });

  final String label;
  final int value;
  final int max;
  final String? valueText;
  final Color? color;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              const SizedBox(width: 8),
              Text(valueText ?? '$value',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          if (sub != null && sub!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : value / max,
              minHeight: 8,
              color: c,
              backgroundColor: c.withAlpha(30),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: child,
      ),
    );
  }
}
