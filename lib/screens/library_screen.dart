import 'package:flutter/material.dart';

import '../services/library_service.dart';
import '../strings.dart';
import '../widgets/paper_card.dart';
import 'paper_sheet.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lib = LibraryService.instance;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: lib,
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
                          return PaperCard(
                            paper: p,
                            onTap: () => showPaperSheet(context, p),
                            trailing: IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.bookmark),
                              onPressed: () => lib.toggle(p),
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
