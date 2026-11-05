import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:scinode/models/note.dart';
import 'package:scinode/screens/notes_screen.dart';
import 'package:scinode/services/note_service.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/widgets/math_markdown.dart';
import 'package:scinode/widgets/math_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Формулы, которые найдёт Markdown-разбор (как при отображении).
List<String> parsedMath(String text) {
  final doc = md.Document(extensionSet: MathMarkdown.extensions);
  final out = <String>[];
  void walk(List<md.Node> nodes) {
    for (final n in nodes) {
      if (n is md.Element) {
        if (n.tag == 'latex') {
          out.add('${n.attributes['MathStyle']}:${n.textContent}');
        } else {
          walk(n.children ?? const []);
        }
      }
    }
  }

  walk(doc.parseLines(text.split('\n')));
  return out;
}

void main() {
  group('Распознавание формул', () {
    test('в строке, блоком, \\( \\) и \\[ \\]', () {
      expect(parsedMath(r'Энергия $E=mc^2$ и $x$.'), ['text:E=mc^2', 'text:x']);
      expect(parsedMath('Вывод:\n\n\$\$\n\\int_0^1 x\\,dx\n\$\$\n\nконец'),
          [r'display:\int_0^1 x\,dx']);
      expect(parsedMath(r'Сумма $$\sum_i a_i$$ в строке'),
          [r'display:\sum_i a_i']);
      expect(parsedMath(r'Скобки \(a+b\) и \[c\]'), ['text:a+b', 'display:c']);
    });

    test('деньги и экранированный доллар — не формулы', () {
      expect(parsedMath(r'Стоит $5 и $10 в месяц'), isEmpty);
      expect(parsedMath(r'Pro за $5, лаборатория за $100'), isEmpty);
      expect(parsedMath(r'Знак \$ и ещё \$'), isEmpty);
      expect(parsedMath(r'Пробел внутри $ x$ не формула'), isEmpty);
      // Пробел перед закрывающим $ допустим (после кнопок вида \partial).
      expect(parsedMath(r'Знак $\partial $ тут'), [r'text:\partial']);
    });

    test('подчёркивание в формуле не становится курсивом', () {
      expect(parsedMath(r'Индексы $a_i + b_j$ и _курсив_'), ['text:a_i + b_j']);
    });

    test('findFormulas совпадает с отображением', () {
      const text = 'Цена \$5. Формула \$a_i\$, блок:\n\$\$\nx^2\n\$\$\n\\(y\\)';
      final f = findFormulas(text);
      expect(f.map((x) => '${x.display}:${x.texOf(text)}'),
          ['false:a_i', 'true:x^2', 'false:y']);
      expect(allFormulas(text), ['a_i', 'x^2', 'y']);
    });

    test('курсор внутри формулы', () {
      const text = r'До $\frac{a}{b}$ после';
      final inside = text.indexOf('a}');
      expect(formulaAt(text, inside)?.texOf(text), r'\frac{a}{b}');
      expect(formulaAt(text, 1), isNull);
      expect(insideMath(text, inside), isTrue);
      expect(insideMath(text, text.length), isFalse);
      // Незакрытая формула.
      expect(insideMath(r'Пишу $\alpha + ', 14), isTrue);
    });

    test('проверка формулы', () {
      expect(texError(r'\frac{a}{b}'), isNull);
      expect(texError(r'\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}'), isNull);
      expect(texError(r'\frac{a}{'), isNotNull);
      expect(texError(r'\неткоманды'), isNotNull);
      expect(texError(''), isNull);
    });
  });

  group('Вставка кнопками', () {
    test('вне формулы шаблон оборачивается в \$…\$, курсор внутри', () {
      final e = insertSnippet('Итак ', 5, 5, r'\frac{¦}{}');
      expect(e.text, r'Итак $\frac{}{}$');
      expect(e.selStart, 'Итак \$\\frac{'.length);
    });

    test('внутри формулы — без обёртки', () {
      const t0 = r'$x + $';
      final e = insertSnippet(t0, 5, 5, r'\sqrt{¦}');
      expect(e.text, r'$x + \sqrt{}$');
    });

    test('выделенный текст попадает в шаблон', () {
      const t0 = r'$a+b$';
      final e = insertSnippet(t0, 1, 4, r'\sqrt{¦}');
      expect(e.text, r'$\sqrt{a+b}$');
      expect(e.text.substring(e.selStart, e.selEnd), 'a+b');
    });

    test('оформление текста не оборачивается', () {
      final e = insertSnippet('слово', 0, 5, '**¦**', math: false);
      expect(e.text, '**слово**');
    });

    test('все кнопки панели дают правильные формулы', () {
      for (final k in mathKeys) {
        if (!k.math) continue;
        final e = insertSnippet('', 0, 0, k.snippet);
        final tex = allFormulas(e.text.replaceAll('¦', ''));
        expect(tex.length, 1, reason: k.snippet);
        expect(texError(tex.single), isNull, reason: k.snippet);
        if (k.tex) expect(texError(k.label), isNull, reason: k.label);
      }
    });

    test('applyMathKey меняет поле ввода', () {
      final c = TextEditingController(text: 'x');
      c.selection = const TextSelection.collapsed(offset: 1);
      applyMathKey(c, mathKeys.firstWhere((k) => k.tip == 'nt.k.pow'));
      expect(c.text, r'x$^{}$');
      expect(c.selection.baseOffset, 'x\$^{'.length);
    });
  });

  group('Модель заметки', () {
    test('чтение, заголовок, фильтры, сортировка', () {
      final n = Note.fromMap('n1', {
        'o': 'u',
        't': '',
        'b': '# Вывод\nТекст',
        'p': {'id': 'W1', 't': 'Статья', 'doi': '10.1/x', 'pg': 4},
        'c': null,
      });
      expect(n.displayTitle, 'Вывод');
      expect(n.paper?.page, 4);
      expect(n.card, isNull);
      expect(noteMatches(n, NoteFilter.papers, ''), isTrue);
      expect(noteMatches(n, NoteFilter.tasks, ''), isFalse);
      expect(noteMatches(n, NoteFilter.all, 'статья'), isTrue);
      expect(noteMatches(n, NoteFilter.all, 'нет такого'), isFalse);
      final free = Note.fromMap('n2', {'o': 'u', 'b': 'x'});
      expect(noteMatches(free, NoteFilter.free, ''), isTrue);
      final sorted = sortNotes([
        Note(id: 'a', owner: 'u', updated: DateTime(2026, 1, 1)),
        Note(id: 'b', owner: 'u', updated: DateTime(2026, 5, 1)),
        const Note(id: 'c', owner: 'u'),
      ]);
      expect(sorted.map((x) => x.id), ['c', 'b', 'a']);
      expect(NotePaper.fromMap({'id': 'x', 't': 'y', 'pg': 0})?.page, isNull);
    });
  });

  group('NoteService', () {
    test('создание, сохранение, привязки, удаление', () async {
      final db = FakeFirebaseFirestore();
      final s = NoteService(db: db, uid: () => 'alice');
      final r = s.create(
          title: 'Т',
          body: r'$E=mc^2$',
          paper: const NotePaper(id: 'W1', title: 'Статья', page: 2));
      await r.done;
      final doc = await db.collection('notes').doc(r.id).get();
      expect(doc['o'], 'alice');
      expect(doc['p'], {'id': 'W1', 't': 'Статья', 'pg': 2});
      expect(doc['c'], isNull);

      await s.save(r.id, title: ' Новый ', body: 'x' * 30000);
      final n = (await s.notes().first).single;
      expect(n.title, 'Новый');
      expect(n.body.length, maxNoteBody);

      await s.setCard(
          r.id, const NoteCard(boardId: 'b', cardId: 'c', title: 'Задача'));
      expect((await s.note(r.id).first)?.card?.cardId, 'c');

      // Чужие заметки не попадают в список.
      await NoteService(db: db, uid: () => 'bob').create(body: 'чужая').done;
      expect((await s.notes().first).length, 1);

      await s.deleteAllMine();
      expect((await s.notes().first), isEmpty);
      expect((await db.collection('notes').get()).docs.length, 1);
    });
  });

  group('Экраны заметок', () {
    late FakeFirebaseFirestore db;
    late NoteService svc;

    setUp(() {
      Strings.instance.lang = 'ru';
      SharedPreferences.setMockInitialValues({});
      db = FakeFirebaseFirestore();
      svc = NoteService(db: db, uid: () => 'alice');
    });

    Future<void> pump(WidgetTester tester, Widget w) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: w));
      await tester.pumpAndSettle();
    }

    testWidgets('новая заметка: кнопка формулы, живой просмотр, сохранение',
        (tester) async {
      await pump(tester, NoteEditorScreen(service: svc));
      await tester.enterText(find.byType(TextField).first, 'Закон');
      await tester.tap(find.byType(TextField).last);
      await tester.pump();
      await tester.tap(find.byTooltip('Дробь'));
      await tester.pump();
      final body = tester
          .widget<TextField>(find.byType(TextField).last)
          .controller!
          .text;
      expect(body, r'$\frac{}{}$');
      // Над панелью — готовая формула под курсором.
      expect(find.byType(Math), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      final docs = (await db.collection('notes').get()).docs;
      expect(docs.length, 1);
      expect(docs.single['t'], 'Закон');
      expect(docs.single['b'], r'$\frac{}{}$');

      // Просмотр.
      await tester.tap(find.byTooltip('Просмотр'));
      await tester.pumpAndSettle();
      expect(find.byType(MathMarkdown), findsOneWidget);
    });

    testWidgets('пустая новая заметка не сохраняется', (tester) async {
      await pump(tester, NoteEditorScreen(service: svc));
      await tester.pumpWidget(const SizedBox()); // экран закрыт
      await tester.pump();
      expect((await db.collection('notes').get()).docs, isEmpty);
    });

    testWidgets('список: заметки, фильтр и поиск', (tester) async {
      await svc
          .create(
              title: 'К статье',
              body: r'$x^2$',
              paper: const NotePaper(id: 'W1', title: 'Статья'))
          .done;
      await svc.create(title: 'Своя мысль', body: 'текст').done;
      await pump(tester, NotesScreen(service: svc));
      expect(find.text('К статье'), findsOneWidget);
      expect(find.text('Своя мысль'), findsOneWidget);
      expect(find.text('формул: 1'), findsOneWidget);
      await tester.tap(find.text('К статьям'));
      await tester.pumpAndSettle();
      expect(find.text('Своя мысль'), findsNothing);
      await tester.tap(find.text('Все'));
      await tester.enterText(find.byType(TextField), 'мысль');
      await tester.pumpAndSettle();
      expect(find.text('К статье'), findsNothing);
      expect(find.text('Своя мысль'), findsOneWidget);
    });
  });

  group('Вёрстка на узком телефоне с крупным шрифтом', () {
    for (final lang in ['ru', 'uz', 'en']) {
      testWidgets('редактор и список ($lang)', (tester) async {
        Strings.instance.lang = lang;
        SharedPreferences.setMockInitialValues({});
        final svc =
            NoteService(db: FakeFirebaseFirestore(), uid: () => 'alice');
        final r = svc.create(
            title: 'Очень длинный заголовок заметки про уравнение Шрёдингера',
            body: '\$\$\n\\int_{-\\infty}^{\\infty} e^{-x^2}\\,dx '
                '= \\sqrt{\\pi} + \\sum_{n=0}^{\\infty} \\frac{x^n}{n!}\n\$\$',
            paper: const NotePaper(
                id: 'W1',
                title: 'Очень длинное название статьи о квантовой механике',
                page: 12));
        await r.done;
        tester.view.physicalSize = const Size(640, 1280);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        Widget wrap(Widget w) => MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(1.2)),
                child: child!,
              ),
              home: w,
            );
        await tester.pumpWidget(wrap(NotesScreen(service: svc)));
        await tester.pumpAndSettle();
        await tester
            .pumpWidget(wrap(NoteEditorScreen(noteId: r.id, service: svc)));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.visibility));
        await tester.pumpAndSettle();
      });
    }
  });
}
