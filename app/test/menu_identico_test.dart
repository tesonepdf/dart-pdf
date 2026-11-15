// Paletto 1 (conflittiFusione.md): il menu e' identico su tutti i sistemi,
// stesse voci, stesso ordine, stessi nomi. Cambia solo come ci si arriva.
// Qui si costruisce il menu per Android, iOS, Windows, macOS e Linux e si
// confronta con quello di Android. Il web ha la stessa prova in
// `flutter test --platform chrome test/menu_identico_test.dart`
// (il web e' un solo sistema: kIsWeb non si puo' simulare).
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/editor_screen.dart';
import 'test_finders.dart';

/// Elenco ordinato di "id|titolo" di ogni voce del menu e di ogni macroarea.
List<String> _menuEntries(WidgetTester tester) {
  final out = <String>[];
  // Ogni riga del menu ha come chiave l'id del comando (anche senza il
  // prefisso "menu-"): si prendono tutte le chiavi di testo dentro il menu.
  final rows = find.descendant(
    of: find.byKey(const ValueKey('app-menu')),
    matching: find.byWidgetPredicate((w) => w.key is ValueKey<String>),
  );
  for (final element in rows.evaluate()) {
    final id = (element.widget.key! as ValueKey<String>).value;
    final texts = find
        .descendant(of: find.byWidget(element.widget), matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.isNotEmpty)
        .join(' / ');
    out.add('$id|$texts');
  }
  return out;
}

void main() {
  late PdfEditingPreferences prefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    prefs = PdfEditingPreferences();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    prefs.dispose();
  });

  Future<List<String>> build(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    // Finestra alta e larga: nessuna voce resta fuori dalla lista.
    tester.view.physicalSize = const Size(1400, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: ValueKey(platform),
      home: EditorScreen(
        prefs: prefs,
        initialDocument: (bytes: buildClassicPdf(), title: 'Report.pdf'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await openAppMenu(tester);
    return _menuEntries(tester);
  }

  testWidgets('il menu e\' identico su Android, iOS, Windows, macOS e Linux',
      (tester) async {
    final android = await build(tester, TargetPlatform.android);
    expect(android, isNotEmpty);
    // Le voci che prima sparivano su alcuni sistemi ci sono sempre.
    for (final id in [
      'open-in-word',
      'open-in-excel',
      'menu-open-with-rank',
      'menu-whatsapp-contact',
      'menu-whatsapp',
      'menu-share',
      'menu-tools',
      'ocr',
      'updates',
    ]) {
      expect(android.any((e) => e.startsWith('$id|')), isTrue, reason: id);
    }
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    ]) {
      await tester.pumpWidget(const SizedBox());
      final other = await build(tester, platform);
      expect(other, android, reason: 'menu diverso su ${platform.name}');
    }
  });
}
