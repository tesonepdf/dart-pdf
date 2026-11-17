// La schermata Crea: griglia di azioni rapide a 4 colonne.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_pdf_editor_app/create_screen.dart';

void main() {
  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> pumpCreate(
    WidgetTester tester,
    List<CreateSection> sections,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('go-create'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => CreateScreen(sections: sections),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(key('go-create'));
    await tester.pumpAndSettle();
  }

  CreateAction action(String id, String label, {VoidCallback? run}) =>
      CreateAction(
          id: id, icon: Icons.add, label: label, run: run ?? () {});

  testWidgets('mostra le azioni rapide e il titolo dei blocchi',
      (tester) async {
    await pumpCreate(tester, [
      CreateSection(actions: [
        action('new-document', 'Nuovo documento'),
        action('scan-document', 'Nuova scansione'),
      ]),
      CreateSection(
        title: 'Importa foto con misura',
        actions: [action('import-a4', 'Foglio A4')],
      ),
    ]);

    expect(find.text('Azioni rapide'), findsOneWidget);
    expect(find.text('Importa foto con misura'), findsOneWidget);
    expect(key('create-action-new-document'), findsOneWidget);
    expect(key('create-action-scan-document'), findsOneWidget);
    expect(key('create-action-import-a4'), findsOneWidget);
  });

  testWidgets('la griglia ha quattro colonne', (tester) async {
    await pumpCreate(tester, [
      CreateSection(actions: [
        for (final i in [1, 2, 3, 4, 5]) action('a$i', 'Azione $i'),
      ]),
    ]);

    final tops = [
      for (final i in [1, 2, 3, 4, 5])
        tester.getTopLeft(key('create-action-a$i')).dy,
    ];
    expect(tops[0], tops[3]); // le prime quattro stanno sulla stessa riga
    expect(tops[4], greaterThan(tops[0])); // la quinta va a capo
  });

  testWidgets('toccare un\'azione la esegue e chiude la schermata',
      (tester) async {
    var ran = 0;
    await pumpCreate(tester, [
      CreateSection(actions: [
        action('new-document', 'Nuovo documento', run: () => ran++),
      ]),
    ]);

    await tester.tap(key('create-action-new-document'));
    await tester.pumpAndSettle();

    expect(ran, 1);
    expect(key('create-screen'), findsNothing);
  });
}
