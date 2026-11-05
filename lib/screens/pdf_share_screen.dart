import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../strings.dart';

/// Просмотр готового PDF с кнопками «Сохранить» и «Поделиться».
class PdfShareScreen extends StatefulWidget {
  const PdfShareScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.build,
  });
  final String title;
  final String fileName;
  final Future<Uint8List> Function() build;

  @override
  State<PdfShareScreen> createState() => _PdfShareScreenState();
}

class _PdfShareScreenState extends State<PdfShareScreen> {
  late final Future<Uint8List> _pdf = widget.build();

  Future<void> _share() async {
    final bytes = await _pdf;
    await Printing.sharePdf(bytes: bytes, filename: widget.fileName);
  }

  Future<void> _save() async {
    final bytes = await _pdf;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('rp.save_hint'))));
    await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: widget.fileName.replaceAll('.pdf', ''));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (ctx, s) {
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t('rp.err'), textAlign: TextAlign.center),
              ),
            );
          }
          if (!s.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(t('rp.building')),
                ],
              ),
            );
          }
          return PdfPreview(
            build: (_) async => s.data!,
            useActions: false,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: widget.fileName,
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<Uint8List>(
        future: _pdf,
        builder: (ctx, s) => !s.hasData
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54)),
                          onPressed: _save,
                          icon: const Icon(Icons.save_alt),
                          label: Text(t('rp.save')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share),
                          label: Text(t('rp.share')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
