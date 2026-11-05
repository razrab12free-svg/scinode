import 'package:flutter/material.dart';

import '../models/library_view.dart';
import '../models/paper.dart';
import '../services/library_service.dart';
import '../services/pdf_store.dart';
import '../services/reading_progress.dart';
import '../strings.dart';
import 'zotero_screen.dart';
import '../widgets/paper_card.dart';
import 'paper_actions.dart';

/// Библиотека: все сохранённые и скачанные статьи, отсюда же читаем PDF.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _search = TextEditingController();
  LibFilter _filter = LibFilter.all;
  LibSort _sort = LibSort.recent;

  @override
  void initState() {
    super.initState();
    LibraryService.instance.ensureLoaded();
    PdfStore.instance.ensureLoaded();
    ReadingProgress.instance.ensureLoaded();
    _search.addListener(_onSearch);
  }

  void _onSearch() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _openZotero() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const ZoteroScreen()));

  void _reset() {
    _search.clear();
    setState(() => _filter = LibFilter.all);
  }

  Widget _header(int total) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('tab.library'),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                if (total > 0)
                  Text(t('lib.count', {'n': total}),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: const Icon(Icons.sync_alt, size: 18, color: zoteroAccent),
              label: Text(t('zt.button')),
              tooltip: t('zt.title'),
              onPressed: _openZotero,
            ),
          ),
          if (total > 0)
            PopupMenuButton<LibSort>(
              tooltip: t('lib.sort'),
              icon: const Icon(Icons.sort),
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (_) => [
                for (final s in LibSort.values)
                  CheckedPopupMenuItem(
                    value: s,
                    checked: s == _sort,
                    child: Text(t('lib.sort.${s.name}')),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: t('lib.search'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).deleteButtonTooltip,
                      icon: const Icon(Icons.clear),
                      onPressed: _search.clear,
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              for (final f in LibFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: f == LibFilter.pdf
                        ? const Icon(Icons.picture_as_pdf_outlined, size: 18)
                        : null,
                    label: Text(t(switch (f) {
                      LibFilter.all => 'lib.f.all',
                      LibFilter.pdf => 'lib.f.pdf',
                      LibFilter.noPdf => 'lib.f.nopdf',
                    })),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.library_books, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(t('lib.empty_title'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(t('lib.empty_text'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  foregroundColor: zoteroAccent),
              onPressed: _openZotero,
              icon: const Icon(Icons.sync_alt),
              label: Text(t('zt.lib_import')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nothing() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Icon(Icons.search_off, size: 48),
        const SizedBox(height: 12),
        Text(t('lib.nothing'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
            onPressed: _reset,
            child: Text(t('lib.reset')),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = LibraryService.instance;
    final store = PdfStore.instance;
    final reading = ReadingProgress.instance;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([lib, store, reading]),
        builder: (context, _) {
          final all = lib.items;
          final shown = filterLibrary(
            all,
            query: _search.text,
            filter: _filter,
            sort: _sort,
            hasPdf: (p) => store.has(PdfStore.idOf(p)),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(all.length),
              if (all.isNotEmpty) _controls(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: all.isEmpty
                      ? _empty()
                      : shown.isEmpty
                          ? _nothing()
                          : ListView.builder(
                              key: ValueKey('${_filter.name}-${_sort.name}'),
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: shown.length,
                              itemBuilder: (_, i) =>
                                  _LibraryCard(paper: shown[i]),
                            ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Карточка статьи в библиотеке: значок PDF с размером, прогресс чтения,
/// прогресс скачивания и меню действий.
class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.paper});
  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = PdfStore.instance;
    final id = PdfStore.idOf(paper);
    final has = store.has(id);
    final downloading = store.isDownloading(id);
    final pos = has ? ReadingProgress.instance.of(id) : null;

    Widget? footer;
    if (downloading) {
      final prog = store.progressOf(id);
      footer = LinearProgressIndicator(
        value: prog > 0 ? prog : null,
        minHeight: 4,
        borderRadius: BorderRadius.circular(4),
      );
    } else if (pos != null) {
      footer = Row(
        children: [
          Icon(Icons.auto_stories_outlined,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            pos.pages > 0
                ? t('lib.progress', {'p': pos.page, 'n': pos.pages})
                : t('lib.progress_page', {'p': pos.page}),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (pos.pages > 0) ...[
            const SizedBox(width: 10),
            Expanded(
              child: LinearProgressIndicator(
                value: pos.fraction,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      );
    }

    return PaperCard(
      paper: paper,
      hasPdf: has,
      pdfLabel: has ? 'PDF · ${formatBytes(store.sizeOf(id))}' : null,
      onTap: () => openPaper(context, paper),
      onLongPress: () => showPaperActions(context, paper),
      footer: footer,
      trailing: IconButton(
        tooltip: t('lib.more'),
        icon: const Icon(Icons.more_vert),
        onPressed: () => showPaperActions(context, paper),
      ),
    );
  }
}
