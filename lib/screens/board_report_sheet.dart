import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/board_report.dart';
import '../models/grant.dart' show formatDate;
import '../services/report_pdf.dart';
import '../strings.dart';
import '../widgets/board_widgets.dart';
import 'pdf_share_screen.dart';

/// Панель настройки PDF-отчёта: период и разделы.
Future<void> showReportSheet(
    BuildContext context, Board board, List<TaskCard> cards) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(board: board, cards: cards),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.board, required this.cards});
  final Board board;
  final List<TaskCard> cards;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportPeriod _period = ReportPeriod.week;
  DateTimeRange? _custom;
  final Set<ReportSection> _sections = ReportSection.values.toSet();

  ReportRange get _range => ReportRange.of(_period, DateTime.now(),
      customFrom: _custom?.start, customTo: _custom?.end);

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom ??
          DateTimeRange(
              start: now.subtract(const Duration(days: 13)), end: now),
    );
    if (r == null || !mounted) return;
    setState(() {
      _custom = r;
      _period = ReportPeriod.custom;
    });
  }

  void _create() {
    if (_sections.isEmpty) {
      toast(context, t('rp.need_section'));
      return;
    }
    final nav = Navigator.of(context);
    final report =
        BoardReport.of(widget.board, widget.cards, _range, DateTime.now());
    nav.pop();
    nav.push(MaterialPageRoute<void>(
      builder: (_) => ReportPreviewScreen(
        report: report,
        sections: {
          for (final s in ReportSection.values)
            if (_sections.contains(s)) s,
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = Strings.instance.lang;
    final r = _range;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('rp.setup_title'),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(t('rp.period'),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in ReportPeriod.values)
                ChoiceChip(
                  label: Text(t('rp.period.${p.name}')),
                  selected: _period == p,
                  showCheckmark: false,
                  onSelected: (_) => p == ReportPeriod.custom
                      ? _pickCustom()
                      : setState(() => _period = p),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t('rp.period_range', {
              'a': formatDate(r.from, lang),
              'b': formatDate(r.lastDay, lang),
            }),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(t('rp.sections'),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          for (final s in ReportSection.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _sections.contains(s),
              title: Text(t('rp.sec.${s.name}')),
              onChanged: (v) => setState(
                  () => v == true ? _sections.add(s) : _sections.remove(s)),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(t('rp.create')),
          ),
        ],
      ),
    );
  }
}

/// Имя файла: «Scinode_Название_2026-11-05.pdf» без запрещённых символов.
String reportFileName(String board, DateTime d) {
  final clean = board
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final short = clean.length > 40 ? clean.substring(0, 40) : clean;
  String two(int x) => x.toString().padLeft(2, '0');
  return 'Scinode_${short}_${d.year}-${two(d.month)}-${two(d.day)}.pdf';
}

/// Просмотр готового отчёта: «Сохранить» и «Поделиться».
class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen(
      {super.key, required this.report, required this.sections});
  final BoardReport report;
  final Set<ReportSection> sections;

  Future<Uint8List> _build() async {
    final r = report;
    final uids = <String>{
      ...r.board.members,
      for (final m in r.members) m.uid,
      for (final c in r.columns)
        for (final x in c.cards) ...x.assignees,
    }..remove('');
    final names = <String, String>{};
    await Future.wait([
      for (final u in uids)
        MemberNames.lookup(u)
            .then((p) => names[u] = p?.name ?? '')
            .catchError((_) => ''),
    ]);
    return buildReportPdf(
      r,
      sections: sections,
      names: names,
      fonts: await loadReportFonts(),
      lang: Strings.instance.lang,
    );
  }

  @override
  Widget build(BuildContext context) => PdfShareScreen(
        title: t('rp.setup_title'),
        fileName: reportFileName(report.board.name, report.generated),
        build: _build,
      );
}
