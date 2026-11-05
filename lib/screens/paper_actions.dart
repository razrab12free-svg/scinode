import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/paper.dart';
import '../services/library_service.dart';
import '../services/pdf_store.dart';
import '../services/reading_progress.dart';
import '../strings.dart';
import '../utils.dart';
import 'paper_sheet.dart';
import 'pdf_reader_screen.dart';

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Есть ли у статьи легальная открытая версия, которую можно скачать.
bool canDownloadPdf(Paper p) =>
    p.pdfUrl != null || (p.isOa && p.doiShort != null);

/// Открывает читалку, если PDF на месте. Возвращает false, если файла нет.
bool openReader(BuildContext context, Paper p) {
  final store = PdfStore.instance;
  final id = PdfStore.idOf(p);
  if (!store.verify(id)) return false;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PdfReaderScreen(paper: p, path: store.pathOf(id)!),
  ));
  return true;
}

/// Нажатие на статью: со скачанным PDF — сразу читалка, иначе карточка.
void openPaper(BuildContext context, Paper p) {
  if (!openReader(context, p)) showPaperSheet(context, p);
}

/// Скачивает PDF статьи в библиотеку и сообщает результат.
Future<void> downloadPdf(BuildContext context, Paper p) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  try {
    await PdfStore.instance.download(p);
    say(t('lib.downloaded'));
  } on DownloadException catch (e) {
    if (e.kind != 'cancelled') say(t('pdf.err.${e.kind}'));
  } catch (_) {
    say(t('pdf.err.network'));
  }
}

/// Удаляет только файл PDF; статья остаётся в библиотеке.
Future<void> removePdf(BuildContext context, Paper p) async {
  await PdfStore.instance.remove(PdfStore.idOf(p));
  if (context.mounted) _toast(context, t('lib.pdf_removed'));
}

/// Удаляет статью из библиотеки вместе с PDF (после подтверждения).
Future<bool> removeFromLibrary(BuildContext context, Paper p) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(t('lib.act.remove')),
      content: Text(t('lib.act.remove_q')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(t('pdf.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(96, 48),
            backgroundColor: Theme.of(d).colorScheme.error,
            foregroundColor: Theme.of(d).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(d, true),
          child: Text(t('lib.act.delete')),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  final id = PdfStore.idOf(p);
  await PdfStore.instance.remove(id);
  await ReadingProgress.instance.remove(id);
  await LibraryService.instance.remove(p.id);
  if (context.mounted) _toast(context, t('lib.removed'));
  return true;
}

/// Нижняя панель действий со статьёй (меню «⋮» и долгое нажатие).
Future<void> showPaperActions(BuildContext context, Paper p) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final store = PdfStore.instance;
      final id = PdfStore.idOf(p);
      final has = store.has(id);
      final downloading = store.isDownloading(id);
      final inLib = LibraryService.instance.contains(p.id);
      final bottom = MediaQuery.of(ctx).viewPadding.bottom;
      final scheme = Theme.of(ctx).colorScheme;

      Widget item(IconData icon, String label, VoidCallback onTap,
              {Color? color}) =>
          ListTile(
            minTileHeight: 56,
            leading: Icon(icon, color: color),
            title: Text(label, style: TextStyle(color: color)),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );

      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 12 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            if (has)
              item(Icons.menu_book, t('lib.act.read'),
                  () => openPaper(context, p)),
            item(Icons.info_outline, t('lib.act.details'),
                () => showPaperSheet(context, p)),
            if (!has && !downloading && canDownloadPdf(p))
              item(Icons.download, t('lib.act.download'),
                  () => downloadPdf(context, p)),
            if (has)
              item(Icons.delete_sweep_outlined, t('lib.act.remove_pdf'),
                  () => removePdf(context, p)),
            if (p.doiShort != null)
              item(Icons.copy, t('paper.copy_doi'), () async {
                await Clipboard.setData(ClipboardData(text: p.doiShort!));
                if (context.mounted) _toast(context, t('paper.copied'));
              }),
            if (p.articleUrl != null)
              item(Icons.open_in_new, t('paper.open'),
                  () => openLink(context, p.articleUrl!)),
            if (inLib)
              item(Icons.delete_outline, t('lib.act.remove'),
                  () => removeFromLibrary(context, p),
                  color: scheme.error),
          ],
        ),
      );
    },
  );
}
