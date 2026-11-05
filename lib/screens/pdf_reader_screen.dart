import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/paper.dart';
import '../services/pdf_store.dart';
import '../services/reading_progress.dart';
import '../strings.dart';

/// Читалка PDF: помнит последнюю страницу, ночной режим, переход к странице,
/// полноэкранный режим по нажатию на страницу.
class PdfReaderScreen extends StatefulWidget {
  const PdfReaderScreen({super.key, required this.paper, required this.path});
  final Paper paper;
  final String path;

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  static const _invert = ColorFilter.matrix(<double>[
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);
  static const _none = ColorFilter.mode(Colors.transparent, BlendMode.dst);
  static const _anim = Duration(milliseconds: 220);

  late final String _id = PdfStore.idOf(widget.paper);
  PdfViewerController? _controller;
  int _page = 1;
  int _pages = 0;
  bool _night = false;
  bool _full = false;

  @override
  void initState() {
    super.initState();
    ReadingProgress.instance.ensureLoaded();
  }

  @override
  void dispose() {
    ReadingProgress.instance.flush();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _setFull(bool v) {
    if (v == _full) return;
    setState(() => _full = v);
    SystemChrome.setEnabledSystemUIMode(
        v ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  void _onPage(int? p) {
    if (p == null || !mounted) return;
    setState(() => _page = p);
    ReadingProgress.instance.save(_id, p, _pages);
  }

  Future<void> _goTo() async {
    if (_pages <= 0) return;
    final n = await showDialog<int>(
      context: context,
      builder: (_) => _GoToPageDialog(page: _page, pages: _pages),
    );
    if (n != null) await _controller?.goToPage(pageNumber: n);
  }

  Widget _errorView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 56, color: scheme.error),
              const SizedBox(height: 12),
              Text(t('pdf.err.open'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(t('pdf.back')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final saved = ReadingProgress.instance.of(_id);

    final viewer = ColorFiltered(
      colorFilter: _night ? _invert : _none,
      child: PdfViewer.file(
        widget.path,
        params: PdfViewerParams(
          backgroundColor: _night ? Colors.white : scheme.surfaceContainer,
          calculateInitialPageNumber: (doc, _) {
            final p = saved?.page;
            if (p == null || p < 1 || p > doc.pages.length) return null;
            return p;
          },
          onViewerReady: (document, controller) {
            if (!mounted) return;
            _controller = controller;
            // Не затираем сохранённую страницу первой: берём текущую из
            // читалки, а если её ещё нет — сохранённую.
            final n = document.pages.length;
            if (n == 0) return;
            final p = (controller.pageNumber ?? saved?.page ?? 1).clamp(1, n);
            setState(() {
              _pages = n;
              _page = p;
            });
            ReadingProgress.instance.save(_id, p, n);
          },
          onPageChanged: _onPage,
          onGeneralTap: (ctx, controller, d) {
            if (d.type == PdfViewerGeneralTapType.tap) _setFull(!_full);
            return false; // ссылки и выделение работают как обычно
          },
          errorBannerBuilder: (ctx, error, stack, ref) {
            // Битый или пропавший файл: забываем о нём, чтобы статья
            // показывалась без значка PDF.
            PdfStore.instance.verify(_id);
            return _errorView(ctx);
          },
        ),
      ),
    );

    final bar = Material(
      color: scheme.surface.withAlpha(240),
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const BackButton(),
              Expanded(
                child: Text(
                  widget.paper.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: t('pdf.goto'),
                icon: const Icon(Icons.find_in_page_outlined),
                onPressed: _pages > 0 ? _goTo : null,
              ),
              IconButton(
                tooltip: t('pdf.night'),
                icon: Icon(_night ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => setState(() => _night = !_night),
              ),
              IconButton(
                tooltip: t('pdf.fullscreen'),
                icon: const Icon(Icons.fullscreen),
                onPressed: () => _setFull(true),
              ),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_full,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop)
          _setFull(false); // «Назад» сначала выходит из полного экрана
      },
      child: Scaffold(
        backgroundColor: _night ? Colors.black : scheme.surfaceContainer,
        // Stack растягиваем на весь экран: иначе он принимал высоту верхней
        // панели, и от страницы PDF была видна только узкая полоска.
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: _full ? 0 : mq.padding.top + 56),
                child: viewer,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: _anim,
                offset: _full ? const Offset(0, -1) : Offset.zero,
                child: AnimatedOpacity(
                  duration: _anim,
                  opacity: _full ? 0 : 1,
                  child: IgnorePointer(ignoring: _full, child: bar),
                ),
              ),
            ),
            if (_pages > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16 + mq.viewPadding.bottom,
                child: AnimatedOpacity(
                  duration: _anim,
                  opacity: _full ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: _full,
                    child: Center(
                      child: Material(
                        color: scheme.inverseSurface.withAlpha(225),
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _goTo,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              child: Center(
                                widthFactor: 1,
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
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Окно «Перейти к странице».
class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.page, required this.pages});
  final int page;
  final int pages;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: '${widget.page}');
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final n = parsePageNumber(_ctrl.text, widget.pages);
    if (n == null) {
      setState(() => _error = t('pdf.goto_bad', {'n': widget.pages}));
      return;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('pdf.goto')),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: t('pdf.goto_hint', {'n': widget.pages}),
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('pdf.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
          onPressed: _submit,
          child: Text(t('pdf.go')),
        ),
      ],
    );
  }
}

/// Разбирает введённый номер страницы. null — если не число или вне 1..[pages].
int? parsePageNumber(String text, int pages) {
  final n = int.tryParse(text.trim());
  if (n == null || n < 1 || n > pages) return null;
  return n;
}
