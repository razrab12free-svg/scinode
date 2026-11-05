import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/grant.dart';
import '../services/board_service.dart';
import '../services/grants_service.dart';
import '../strings.dart';
import '../utils.dart';
import '../widgets/grant_card.dart';
import 'grant_to_board.dart';

Future<void> showGrantCallSheet(BuildContext context, GrantCall call) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => GrantCallSheet(call: call),
  );
}

Future<void> showFundedProjectSheet(BuildContext context, FundedProject p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FundedProjectSheet(project: p),
  );
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('gr.copied'))));
  }
}

/// Строка «Название: значение».
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          SelectableText(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.url, required this.number});
  final String url;
  final String number;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => openLink(context, url),
          icon: const Icon(Icons.open_in_new),
          label: Text(t('gr.open_site')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => _copy(context, number),
          icon: const Icon(Icons.copy),
          label: Text(t('gr.copy')),
        ),
      ],
    );
  }
}

/// Подробности открытого конкурса.
class GrantCallSheet extends StatefulWidget {
  const GrantCallSheet({super.key, required this.call});
  final GrantCall call;

  @override
  State<GrantCallSheet> createState() => _GrantCallSheetState();
}

class _GrantCallSheetState extends State<GrantCallSheet> {
  Future<GrantCallDetails>? _details;
  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    if (widget.call.source == GrantSource.grantsGov) {
      _details = GrantsService.instance.grantsGovDetails(widget.call.id);
    }
  }

  List<Widget> _detailsBlock(GrantCallDetails d) {
    final c = widget.call;
    final money = <Widget>[
      if (d.totalFunding != null)
        _Row(t('gr.total_funding'), moneyLabel(d.totalFunding!, c.currency)),
      if (d.awardCeiling != null)
        _Row(t('gr.award_ceiling'), moneyLabel(d.awardCeiling!, c.currency)),
      if (d.awardFloor != null)
        _Row(t('gr.award_floor'), moneyLabel(d.awardFloor!, c.currency)),
      if (d.awardsCount != null) _Row(t('gr.awards_count'), '${d.awardsCount}'),
      if (d.costSharing != null)
        _Row(t('gr.cost_sharing'), d.costSharing! ? t('gr.yes') : t('gr.no')),
      if (d.instruments.isNotEmpty)
        _Row(t('gr.instruments'), d.instruments.join(', ')),
      if (d.contactEmail.isNotEmpty) _Row(t('gr.contact'), d.contactEmail),
    ];
    final who = [
      ...d.applicantTypes.map((e) => '• $e'),
      if (d.eligibility.isNotEmpty) d.eligibility,
    ].join('\n');
    return [
      ...money,
      if (who.isNotEmpty) ...[
        _Heading(t('gr.who')),
        SelectableText(who, style: const TextStyle(fontSize: 14, height: 1.4)),
      ],
      if (d.description.isNotEmpty) ...[
        _Heading(t('gr.description')),
        SelectableText(d.description,
            style: const TextStyle(fontSize: 14, height: 1.4)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.call;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final kind = kindLabel(c);
    final later = c.deadlines.skip(1).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(
                text: c.source.label,
                bg: scheme.primary.withAlpha(30),
                fg: scheme.primary,
              ),
              Pill(
                text: statusLabel(c.status),
                bg: scheme.tertiaryContainer,
                fg: scheme.onTertiaryContainer,
              ),
              if (c.deadline != null) DeadlinePill(call: c, now: _now),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(c.title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (c.agency.isNotEmpty) _Row(t('gr.agency'), c.agency),
          if (kind.isNotEmpty) _Row(t('gr.type'), kind),
          _Row(t('gr.number'), c.number),
          _Row(
            t('gr.f.deadline'),
            c.deadline == null
                ? t('gr.no_deadline')
                : '${dateLabel(c.deadline!)} · ${daysLeftLabel(c.deadline!, _now)}',
          ),
          if (c.openDate != null) _Row(t('gr.f.opens'), dateLabel(c.openDate!)),
          if (later.isNotEmpty)
            _Row(t('gr.next_deadlines'), later.map(dateLabel).join(', ')),
          if (c.budget != null)
            _Row(t('gr.budget'), moneyLabel(c.budget!, c.currency)),
          if (_details != null)
            FutureBuilder<GrantCallDetails>(
              future: _details,
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 12),
                        Text(t('gr.details.loading')),
                      ],
                    ),
                  );
                }
                if (snap.hasError || !snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(t('gr.details.err'),
                              style:
                                  TextStyle(fontSize: 13, color: scheme.error)),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48)),
                          onPressed: () => setState(_loadDetails),
                          child: Text(t('gr.retry')),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _detailsBlock(snap.data!),
                );
              },
            ),
          const SizedBox(height: 16),
          InfoNote(text: t('gr.eligibility'), icon: Icons.verified_user),
          const SizedBox(height: 16),
          _Actions(url: c.url, number: c.number),
          // Связка с досками: подготовка заявки как проекта.
          if (BoardService.instance.available) ...[
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              // Доска открывается поверх окна конкурса («Назад» вернёт к нему).
              onPressed: () => prepareApplication(context, c),
              icon: const Icon(Icons.view_kanban_outlined),
              label: Text(t('bd.grant_prepare')),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              style:
                  TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => addGrantToProject(context, c),
              icon: const Icon(Icons.playlist_add),
              label: Text(t('bd.grant_add')),
            ),
          ],
          if (c.source == GrantSource.grantsGov) ...[
            const SizedBox(height: 16),
            Text(t('gr.disclaimer'),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Подробности профинансированного проекта.
class FundedProjectSheet extends StatelessWidget {
  const FundedProjectSheet({super.key, required this.project});
  final FundedProject project;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = project;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final org = [
      if (p.organization.isNotEmpty) p.organization,
      if (p.place.isNotEmpty) p.place,
    ].join('\n');
    final period = [
      if (p.start != null) dateLabel(p.start!),
      if (p.end != null) dateLabel(p.end!),
    ].join(' — ');

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pill(
            text: p.source.label,
            bg: scheme.primary.withAlpha(30),
            fg: scheme.primary,
          ),
          const SizedBox(height: 12),
          SelectableText(p.title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _Row(t('gr.number'), p.number),
          if (org.isNotEmpty) _Row(t('gr.org'), org),
          if (p.investigators.isNotEmpty)
            _Row(t('gr.pi'), p.investigators.join(', ')),
          if (p.amount != null)
            _Row(t('gr.amount'), moneyLabel(p.amount!, p.currency)),
          if (period.isNotEmpty) _Row(t('gr.period'), period),
          if (p.program.isNotEmpty) _Row(t('gr.program'), p.program),
          _Heading(t('gr.abstract')),
          SelectableText(
            p.abstractText.isEmpty ? t('gr.no_abstract') : p.abstractText,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          _Actions(url: p.url, number: p.number),
        ],
      ),
    );
  }
}
