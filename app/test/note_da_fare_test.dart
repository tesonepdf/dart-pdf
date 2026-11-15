import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/settings_screen.dart';

const _chiave = 'dart_pdf_editor_app.note_da_fare';
const _campo = ValueKey('note-da-fare-campo');

Future<void> _apri(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showNoteDaFare(context),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('il testo scritto si salva da solo e si ritrova alla riapertura',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _apri(tester);

    await tester.enterText(find.byKey(_campo), 'comprare il latte');
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_chiave), 'comprare il latte');

    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    final campo = tester.widget<TextField>(find.byKey(_campo));
    expect(campo.controller!.text, 'comprare il latte');
  });

  testWidgets('se c\'era già un testo salvato lo mostra', (tester) async {
    SharedPreferences.setMockInitialValues({_chiave: 'già scritto'});
    await _apri(tester);

    final campo = tester.widget<TextField>(find.byKey(_campo));
    expect(campo.controller!.text, 'già scritto');
  });
}
