import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:scinode/models/paper.dart';
import 'package:scinode/screens/pdf_reader_screen.dart';
import 'package:scinode/strings.dart';

void main() {
  // Ошибка из жалобы владельца: область PDF была высотой с верхнюю панель,
  // и от страницы была видна только узкая полоска.
  testWidgets('область PDF занимает почти весь экран', (tester) async {
    Strings.instance.lang = 'ru';
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: PdfReaderScreen(
        paper: Paper(id: 'W1', title: 'Тестовая статья'),
        path: '/nonexistent/test.pdf',
      ),
    ));
    await tester.pump();

    final screen = tester.getSize(find.byType(PdfReaderScreen));
    final viewer = tester.getSize(find.byType(PdfViewer));
    // Экран 851 dp, панель сверху 56 dp: на PDF должно остаться больше 85%.
    expect(viewer.height, greaterThan(screen.height * 0.85));
    expect(viewer.width, screen.width);

    // Верхняя панель — сверху экрана.
    final bar = tester.getTopLeft(find.text('Тестовая статья'));
    expect(bar.dy, lessThan(100));

    // Полноэкранный режим: страница на весь экран.
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PdfViewer)).height, screen.height);
  });
}
