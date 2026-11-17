// La barra del documento stile tesone: barra strumenti, menu dei triangolini,
// "Altri strumenti" e l'opzione in Impostazioni.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/tesone_bar.dart';
import 'package:dart_pdf_editor_app/bottom_bar_setting.dart';

void main() {
  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> pumpBar(WidgetTester tester, List<TesoneBarItem> items) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: TesoneToolbar(items: items),
        ),
      ));

  test('l\'opzione e\' spenta di base e si salva sul dispositivo', () async {
    SharedPreferences.setMockInitialValues({});
    TesoneBarSetting.instance.value = false;
    expect(TesoneBarSetting.instance.value, isFalse);
    await TesoneBarSetting.instance.save(true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dart_pdf_editor_app.tesone_bar'), isTrue);
  });

  testWidgets('mostra i pulsanti con il nome e toccarne uno lo esegue',
      (tester) async {
    var ran = '';
    await pumpBar(tester, [
      for (final (id, label) in [
        ('edit', 'Modifica PDF'),
        ('comment', 'Commento'),
        ('draw', 'Disegna'),
      ])
        TesoneBarItem(
            id: id,
            icon: Icons.edit,
            label: label,
            run: () => ran = id),
    ]);

    expect(find.text('Modifica PDF'), findsOneWidget);
    expect(find.text('Commento'), findsOneWidget);
    expect(find.text('Disegna'), findsOneWidget);

    await tester.tap(key('tesone-bar-draw'));
    expect(ran, 'draw');
  });

  testWidgets('un pulsante spento non parte', (tester) async {
    var ran = 0;
    await pumpBar(tester, [
      TesoneBarItem(
          id: 'edit',
          icon: Icons.edit,
          label: 'Modifica PDF',
          enabled: false,
          run: () => ran++),
    ]);
    await tester.tap(key('tesone-bar-edit'));
    expect(ran, 0);
  });

  testWidgets('il triangolino apre il menu e una scelta parte',
      (tester) async {
    var ran = '';
    await pumpBar(tester, [
      TesoneBarItem(
        id: 'highlight',
        icon: Icons.border_color,
        label: 'Evidenzia',
        run: () => ran = 'main',
        choices: [
          TesoneChoice(
              id: 'markup-highlight',
              icon: Icons.border_color,
              label: 'Evidenzia',
              run: () => ran = 'highlight'),
          TesoneChoice(
              id: 'markup-underline',
              icon: Icons.format_underlined,
              label: 'Sottolinea',
              run: () => ran = 'underline'),
        ],
      ),
    ]);

    await tester.tap(key('tesone-bar-highlight-menu'));
    await tester.pumpAndSettle();
    expect(key('tesone-choice-markup-underline'), findsOneWidget);

    await tester.tap(key('tesone-choice-markup-underline'));
    await tester.pumpAndSettle();
    expect(ran, 'underline');
    expect(key('tesone-choice-markup-underline'), findsNothing);
  });

  testWidgets('senza scelte non c\'e\' il triangolino', (tester) async {
    await pumpBar(tester, [
      TesoneBarItem(
          id: 'draw', icon: Icons.draw, label: 'Disegna', run: () {}),
    ]);
    expect(key('tesone-bar-draw-menu'), findsNothing);
  });

  testWidgets('Altri strumenti: riquadri a griglia, toccarne uno chiude e parte',
      (tester) async {
    var ran = '';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('go'),
            onPressed: () => showMoreToolsSheet(
              context,
              title: 'Altri strumenti',
              sections: [
                MoreToolsSection(title: 'Inserisci foto, fogli e PDF', tiles: [
                  MoreToolTile(
                      id: 'insert-document',
                      icon: Icons.note_add,
                      label: 'Inserisci PDF',
                      run: () => ran = 'pdf'),
                  MoreToolTile(
                      id: 'compose-sheet',
                      icon: Icons.dashboard,
                      label: 'Componi foglio',
                      run: () => ran = 'sheet'),
                ]),
                MoreToolsSection(title: 'Importa foto con misura', tiles: [
                  MoreToolTile(
                      id: 'import-a4',
                      icon: Icons.description,
                      label: 'Foglio A4',
                      run: () => ran = 'a4'),
                ]),
              ],
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(key('go'));
    await tester.pumpAndSettle();

    expect(find.text('Altri strumenti'), findsOneWidget);
    expect(find.text('Inserisci foto, fogli e PDF'), findsOneWidget);
    expect(find.text('Importa foto con misura'), findsOneWidget);
    expect(key('more-tool-insert-document'), findsOneWidget);

    await tester.tap(key('more-tool-compose-sheet'));
    await tester.pumpAndSettle();
    expect(ran, 'sheet');
    expect(key('more-tools-sheet'), findsNothing);
  });
}
