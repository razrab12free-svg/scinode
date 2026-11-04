import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/paper.dart';
import '../services/library_service.dart';
import '../strings.dart';
import '../utils.dart';

Future<void> showPaperSheet(BuildContext context, Paper p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PaperSheet(paper: p),
  );
}

class PaperSheet extends StatelessWidget {
  const PaperSheet({super.key, required this.paper});
  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = paper;
    final lib = LibraryService.instance;
    final bottom = MediaQuery.of(context).viewPadding.bottom;

    return ListenableBuilder(
      listenable: lib,
      builder: (ctx, _) {
        final saved = lib.contains(p.id);
        final meta = [
          if (p.venue.isNotEmpty) p.venue,
          if (p.year != null) '${p.year}',
        ].join(' · ');
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              if (p.authors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.authors.join(', '), style: const TextStyle(fontSize: 14)),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(meta,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(t('paper.cited', {'n': p.citations}))),
                  Chip(
                    avatar: Icon(
                      p.isOa ? Icons.lock_open : Icons.lock_outline,
                      size: 16,
                    ),
                    label: Text(p.isOa ? t('paper.oa') : t('paper.closed')),
                  ),
                  if (p.topic.isNotEmpty) Chip(label: Text(p.topic)),
                ],
              ),
              const SizedBox(height: 16),
              Text(t('paper.abstract'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                p.abstractText.isEmpty
                    ? t('paper.no_abstract')
                    : p.abstractText,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => lib.toggle(p),
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                label: Text(saved ? t('paper.saved') : t('paper.save')),
              ),
              if (p.pdfUrl != null) ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () => openLink(context, p.pdfUrl!),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(t('paper.pdf')),
                ),
              ],
              if (p.articleUrl != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => openLink(context, p.articleUrl!),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(t('paper.open')),
                ),
              ],
              if (p.doiShort != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: p.doiShort!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                            SnackBar(content: Text(t('paper.copied'))));
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(t('paper.copy_doi')),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
