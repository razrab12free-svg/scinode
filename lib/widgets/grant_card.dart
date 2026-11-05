import 'package:flutter/material.dart';

import '../models/grant.dart';
import '../strings.dart';

/// «Осталось N дней» / «Последний день».
String daysLeftLabel(DateTime deadline, DateTime now) {
  final n = daysLeft(deadline, now);
  if (n <= 0) return t('gr.left.today');
  return t('gr.left.${pluralForm(n, Strings.instance.lang)}', {'n': n});
}

String dateLabel(DateTime d) => formatDate(d, Strings.instance.lang);

String moneyLabel(num amount, String currency) =>
    formatMoney(amount, currency, Strings.instance.lang);

String statusLabel(CallStatus s) => switch (s) {
      CallStatus.open => t('gr.status.open'),
      CallStatus.forthcoming => t('gr.status.forthcoming'),
    };

/// Тип конкурса для показа (пустая строка — не показывать).
String kindLabel(GrantCall c) {
  if (c.source == GrantSource.eu && euGrantTypes.contains(c.kind)) {
    return t('gr.eu.kind.${c.kind}');
  }
  return '';
}

/// Цвета плашки срочности для светлой и тёмной темы.
(Color, Color) urgencyColors(BuildContext context, Urgency u) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (u) {
    Urgency.urgent => (scheme.errorContainer, scheme.onErrorContainer),
    Urgency.soon => dark
        ? (const Color(0xFF5C3B00), const Color(0xFFFFDDB3))
        : (const Color(0xFFFFE0B2), const Color(0xFF6A3A00)),
    Urgency.normal => dark
        ? (const Color(0xFF1E4620), const Color(0xFFB9F6CA))
        : (const Color(0xFFC8E6C9), const Color(0xFF1B5E20)),
    Urgency.none => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
  };
}

/// Маленькая цветная плашка.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
  });
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Плашка «осталось N дней» с цветом срочности.
class DeadlinePill extends StatelessWidget {
  const DeadlinePill({super.key, required this.call, required this.now});
  final GrantCall call;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final d = call.deadline;
    final (bg, fg) = urgencyColors(context, urgencyOf(d, now));
    return Pill(
      text: d == null ? statusLabel(call.status) : daysLeftLabel(d, now),
      bg: bg,
      fg: fg,
      icon: d == null ? Icons.schedule : Icons.timer_outlined,
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag(this.source);
  final GrantSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pill(
      text: source.short,
      bg: scheme.primary.withAlpha(30),
      fg: scheme.primary,
    );
  }
}

/// Карточка открытого конкурса.
class GrantCallCard extends StatelessWidget {
  const GrantCallCard({
    super.key,
    required this.call,
    required this.now,
    required this.onTap,
  });
  final GrantCall call;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final String when;
    if (call.deadline != null) {
      when = t('gr.deadline', {'d': dateLabel(call.deadline!)});
    } else if (call.openDate != null && call.status == CallStatus.forthcoming) {
      when = t('gr.opens', {'d': dateLabel(call.openDate!)});
    } else {
      when = t('gr.no_deadline');
    }
    final forthcomingWithDate =
        call.status == CallStatus.forthcoming && call.deadline != null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SourceTag(call.source),
                  const SizedBox(width: 6),
                  if (forthcomingWithDate)
                    Flexible(
                      child: Pill(
                        text: statusLabel(call.status),
                        bg: scheme.tertiaryContainer,
                        fg: scheme.onTertiaryContainer,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: DeadlinePill(call: call, now: now),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                call.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (call.agency.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(call.agency,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(when, style: muted)),
                  if (call.budget != null)
                    Flexible(
                      child: Text(moneyLabel(call.budget!, call.currency),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted.copyWith(fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка профинансированного проекта.
class FundedProjectCard extends StatelessWidget {
  const FundedProjectCard({
    super.key,
    required this.project,
    required this.onTap,
  });
  final FundedProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = project;
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final period = [
      if (p.start != null) dateLabel(p.start!),
      if (p.end != null) dateLabel(p.end!),
    ].join(' — ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SourceTag(p.source),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: p.amount == null
                          ? const SizedBox.shrink()
                          : Pill(
                              text: moneyLabel(p.amount!, p.currency),
                              bg: scheme.secondaryContainer,
                              fg: scheme.onSecondaryContainer,
                              icon: Icons.payments_outlined,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                p.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (p.organization.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.organization,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
              ],
              if (p.investigators.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(p.investigators.first,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
              ],
              if (period.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.date_range,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(child: Text(period, style: muted)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Плашка ошибки источника с кнопкой «Повторить».
class SourceErrorBanner extends StatelessWidget {
  const SourceErrorBanner({
    super.key,
    required this.source,
    required this.kind,
    required this.onRetry,
  });
  final GrantSource source;
  final String kind;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t('gr.err.$kind', {'src': source.label}),
              style: TextStyle(fontSize: 14, color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: scheme.onErrorContainer,
            ),
            onPressed: onRetry,
            child: Text(t('gr.retry')),
          ),
        ],
      ),
    );
  }
}

/// Строка «Источник: загрузка…».
class SourceLoadingRow extends StatelessWidget {
  const SourceLoadingRow({super.key, required this.source});
  final GrantSource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(t('gr.loading', {'src': source.label}))),
        ],
      ),
    );
  }
}

/// Информационная плашка (eligibility, примечания).
class InfoNote extends StatelessWidget {
  const InfoNote(
      {super.key, required this.text, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onTertiaryContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
