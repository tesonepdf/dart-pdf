// La schermata Strumenti: schede in alto e griglia a 2 colonne.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_pdf_editor_app/tools_screen.dart';

void main() {
  Finder key(String k) => find.byKey(ValueKey(k));

  ToolItem item(String id, ToolTab tab, {VoidCallback? run}) => ToolItem(
        id: id,
        icon: Icons.build,
        title: 'Titolo $id',
        description: 'Descrizione $id',
        tab: tab,
        run: run ?? () {},
      );

  Future<void> pumpTools(WidgetTester tester, List<ToolItem> items) async {
    // Schermo alto: la griglia costruisce solo le righe visibili, e l'ultima
    // sta fuori da quello di prova (800x600).
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('go-tools'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => ToolsScreen(items: items)),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(key('go-tools'));
    await tester.pumpAndSettle();
  }

  final items = [
    item('read-aloud', ToolTab.read),
    item('new-document', ToolTab.create),
    item('ocr', ToolTab.edit),
    item('watermark', ToolTab.edit),
    item('export-word', ToolTab.convert),
  ];

  testWidgets('Tutti mostra ogni strumento con titolo e descrizione',
      (tester) async {
    await pumpTools(tester, items);

    for (final i in items) {
      expect(key('tool-${i.id}'), findsOneWidget, reason: i.id);
    }
    expect(find.text('Titolo ocr'), findsOneWidget);
    expect(find.text('Descrizione ocr'), findsOneWidget);
  });

  testWidgets('le schede sono Tutti, Leggi, Crea, Modifica, Converti, Altro',
      (tester) async {
    await pumpTools(tester, items);

    for (final t in ['all', 'read', 'create', 'edit', 'convert', 'other']) {
      expect(key('tools-tab-$t'), findsOneWidget, reason: t);
    }
  });

  testWidgets('una scheda mostra solo i suoi strumenti', (tester) async {
    await pumpTools(tester, items);

    await tester.tap(key('tools-tab-edit'));
    await tester.pumpAndSettle();

    expect(key('tool-ocr'), findsOneWidget);
    expect(key('tool-watermark'), findsOneWidget);
    expect(key('tool-new-document'), findsNothing);
    expect(key('tool-export-word'), findsNothing);
  });

  testWidgets('una scheda senza strumenti lo dice', (tester) async {
    await pumpTools(tester, items);

    await tester.tap(key('tools-tab-other'));
    await tester.pumpAndSettle();

    expect(key('tools-empty'), findsOneWidget);
  });

  testWidgets('la griglia ha due colonne', (tester) async {
    await pumpTools(tester, items);

    final a = tester.getTopLeft(key('tool-read-aloud'));
    final b = tester.getTopLeft(key('tool-new-document'));
    final c = tester.getTopLeft(key('tool-ocr'));
    expect(a.dy, b.dy); // i primi due sulla stessa riga
    expect(b.dx, greaterThan(a.dx));
    expect(c.dy, greaterThan(a.dy)); // il terzo va a capo
  });

  testWidgets('toccare uno strumento lo esegue e chiude la schermata',
      (tester) async {
    var ran = 0;
    await pumpTools(tester, [
      item('ocr', ToolTab.edit, run: () => ran++),
    ]);

    await tester.tap(key('tool-ocr'));
    await tester.pumpAndSettle();

    expect(ran, 1);
    expect(key('tools-screen'), findsNothing);
  });
}
