import 'package:dart_pdf_editor_app/page_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePageList', () {
    test('pagine singole e intervalli, da 0 e in ordine', () {
      expect(parsePageList('1,3,5-7', 10), [0, 2, 4, 5, 6]);
      expect(parsePageList('7, 5-6 ;1', 10), [0, 4, 5, 6]);
    });

    test('nessun doppione', () {
      expect(parsePageList('2,2,1-3', 5), [0, 1, 2]);
    });

    test('testo vuoto, pagina che non esiste o intervallo al contrario: null',
        () {
      expect(parsePageList('', 5), isNull);
      expect(parsePageList('6', 5), isNull);
      expect(parsePageList('0', 5), isNull);
      expect(parsePageList('4-2', 5), isNull);
      expect(parsePageList('a', 5), isNull);
      expect(parsePageList('1-2-3', 5), isNull);
    });
  });

  group('askPageChoice', () {
    PageChoice? result;
    var asked = false;

    Future<void> open(WidgetTester tester) async {
      result = null;
      asked = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await askPageChoice(context,
                    pageCount: 5, currentPage: 2);
                asked = true;
              },
              child: const Text('apri'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
    }

    testWidgets('di base manda tutto il documento', (tester) async {
      await open(tester);
      expect(find.text('Tutto il documento (5 pagine)'), findsOneWidget);
      expect(find.text('Solo questa pagina (3)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('page-choice-ok')));
      await tester.pumpAndSettle();
      expect(asked, isTrue);
      expect(result!.pages, isNull);
    });

    testWidgets('solo questa pagina', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('page-choice-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('page-choice-ok')));
      await tester.pumpAndSettle();
      expect(result!.pages, [2]);
    });

    testWidgets('alcune pagine: valide e non valide', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('page-choice-2')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey('page-choice-pages')), '9');
      await tester.tap(find.byKey(const ValueKey('page-choice-ok')));
      await tester.pump();
      expect(find.textContaining('Pagine non valide'), findsOneWidget);
      expect(asked, isFalse, reason: 'la finestra resta aperta');

      await tester.enterText(
          find.byKey(const ValueKey('page-choice-pages')), '1,3-4');
      await tester.tap(find.byKey(const ValueKey('page-choice-ok')));
      await tester.pumpAndSettle();
      expect(result!.pages, [0, 2, 3]);
    });

    testWidgets('Annulla non sceglie niente', (tester) async {
      await open(tester);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(asked, isTrue);
      expect(result, isNull);
    });
  });
}
