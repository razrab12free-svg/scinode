import 'package:flutter/material.dart';

import '../services/library_service.dart';
import '../services/pdf_store.dart';
import '../strings.dart';
import '../widgets/paper_card.dart';
import 'paper_sheet.dart';
import 'pdf_reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    LibraryService.instance.ensureLoaded();
    PdfStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lib = LibraryService.instance;
    final store = PdfStore.instance;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([lib, store]),
        builder: (context, _) {
          final items = lib.items;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(t('tab.library'),
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
              ),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(t('lib.count', {'n': items.length}),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
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
                                child: Icon(Icons.library_books,
                                    size: 44, color: scheme.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(t('lib.empty_title'),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Text(t('lib.empty_text'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final p = items[i];
                          final id = PdfStore.idOf(p);
                          final has = store.has(id);
                          return PaperCard(
                            paper: p,
                            hasPdf: has,
                            onTap: () => showPaperSheet(context, p),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (has)
                                  IconButton(
                                    icon: const Icon(Icons.menu_book),
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PdfReaderScreen(
                                          paper: p,
                                          path: store.pathOf(id)!,
                                        ),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.bookmark),
                                  onPressed: () => lib.toggle(p),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
