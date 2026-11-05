import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/paper.dart';
import '../services/library_service.dart';
import '../services/pdf_store.dart';
import '../strings.dart';
import '../utils.dart';
import 'home_shell.dart';
import 'pdf_reader_screen.dart';

Future<void> showPaperSheet(BuildContext context, Paper p) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PaperSheet(paper: p),
  );
}

class PaperSheet extends StatefulWidget {
  const PaperSheet({super.key, required this.paper});
  final Paper paper;

  @override
  State<PaperSheet> createState() => _PaperSheetState();
}

class _PaperSheetState extends State<PaperSheet> {
  String? _msg;

  @override
  void initState() {
    super.initState();
    PdfStore.instance.ensureLoaded();
  }

  Future<void> _download() async {
    setState(() => _msg = null);
    try {
      await PdfStore.instance.download(widget.paper);
    } on DownloadException catch (e) {
      if (e.kind == 'cancelled') return;
      if (mounted) setState(() => _msg = t('pdf.err.${e.kind}'));
    } catch (_) {
      if (mounted) setState(() => _msg = t('pdf.err.network'));
    }
  }

  void _read(String path) {
    final nav = Navigator.of(context);
    // Файл мог пропасть — тогда просто остаёмся в карточке без значка PDF.
    if (!PdfStore.instance.verify(PdfStore.idOf(widget.paper))) return;
    nav.pop();
    nav.push(MaterialPageRoute<void>(
      builder: (_) => PdfReaderScreen(paper: widget.paper, path: path),
    ));
  }

  void _openInLibrary() => HomeShell.goTo(context, HomeShell.libraryTab);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.paper;
    final lib = LibraryService.instance;
    final store = PdfStore.instance;
    final id = PdfStore.idOf(p);
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final canDownload = p.pdfUrl != null || (p.isOa && p.doiShort != null);

    return ListenableBuilder(
      listenable: Listenable.merge([lib, store]),
      builder: (ctx, _) {
        final saved = lib.contains(p.id);
        final has = store.has(id);
        final downloading = store.isDownloading(id);
        final prog = store.progressOf(id);
        final meta = [
          if (p.venue.isNotEmpty) p.venue,
          if (p.year != null) '${p.year}',
        ].join(' · ');

        Widget pdfBlock;
        if (has) {
          pdfBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                onPressed: () => _read(store.pathOf(id)!),
                icon: const Icon(Icons.menu_book),
                label: Text(t('pdf.read')),
              ),
              if (HomeShell.tab.value != HomeShell.libraryTab) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _openInLibrary,
                  icon: const Icon(Icons.library_books_outlined),
                  label: Text(t('lib.open_in_lib')),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('pdf.saved_info',
                          {'size': formatBytes(store.sizeOf(id))}),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => store.remove(id),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(t('pdf.remove')),
                  ),
                ],
              ),
            ],
          );
        } else if (downloading) {
          pdfBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: prog > 0 ? prog : null,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      prog > 0
                          ? t('pdf.downloading', {'p': (prog * 100).round()})
                          : t('pdf.downloading_plain'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => store.cancel(id),
                    child: Text(t('pdf.cancel')),
                  ),
                ],
              ),
            ],
          );
        } else if (canDownload) {
          pdfBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.tonalIcon(
                onPressed: _download,
                icon: const Icon(Icons.download),
                label: Text(t('pdf.download')),
              ),
              const SizedBox(height: 4),
              Text(t('pdf.legal'),
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          );
        } else {
          pdfBlock = const SizedBox.shrink();
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_msg != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: scheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_msg!,
                            style: TextStyle(
                                fontSize: 14, color: scheme.onErrorContainer)),
                      ),
                    ],
                  ),
                ),
              Text(p.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              if (p.authors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.authors.join(', '),
                    style: const TextStyle(fontSize: 14)),
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
              pdfBlock,
              if (!(pdfBlock is SizedBox)) const SizedBox(height: 14),
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
              if (p.pdfUrl != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => openLink(context, p.pdfUrl!),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(t('paper.pdf')),
                ),
              ],
              if (p.doiShort != null) ...[
                const SizedBox(height: 2),
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
