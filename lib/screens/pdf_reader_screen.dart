import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/paper.dart';
import '../strings.dart';

/// Читалка PDF.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key, required this.paper, required this.path});
  final Paper paper;
  final String path;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  static const _invert = ColorFilter.matrix(<double>[
    -1,
    0,
    0,
    0,
    255,
    0,
    -1,
    0,
    0,
    255,
    0,
    0,
    -1,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ]);
  static const _none = ColorFilter.mode(Colors.transparent, BlendMode.dst);

  int _page = 1;
  int _pages = 0;
  bool _night = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.paper.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: t('pdf.night'),
            icon: Icon(_night ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _night = !_night),
          ),
        ],
      ),
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: _night ? _invert : _none,
            child: PdfViewer.file(
              widget.path,
              params: PdfViewerParams(
                onPageChanged: (p) {
                  if (p != null && mounted) setState(() => _page = p);
                },
                onViewerReady: (document, controller) {
                  if (mounted) setState(() => _pages = document.pages.length);
                },
              ),
            ),
          ),
          if (_pages > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.inverseSurface.withAlpha(220),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t('pdf.page', {'p': _page, 'n': _pages}),
                    style: TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
