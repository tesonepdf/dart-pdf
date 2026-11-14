// Annulla e ripeti restano con il documento: la cronologia di una sessione si
// copia (historySnapshot) e si rimette su una sessione nuova aperta dagli
// stessi byte (restoreHistory), anche dopo "aver chiuso l'app".
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_test_fixtures/pdf_test_fixtures.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  PdfEditingController open(Uint8List bytes) {
    SharedPreferences.setMockInitialValues({});
    final c = PdfEditingController(bytes);
    addTearDown(c.dispose);
    return c;
  }

  test('senza modifiche non c e cronologia da conservare', () {
    final c = open(buildMultiPagePdf(1));
    expect(c.historySnapshot, isNull);
  });

  test('due modifiche e un annulla: la cronologia torna su una sessione nuova',
      () {
    final first = open(buildMultiPagePdf(1));
    first.placeCheckMark(0, 100, 100);
    first.placeCheckMark(0, 200, 200);
    first.undo();
    final snapshot = first.historySnapshot!;
    expect(snapshot.revisions.length, 3);
    expect(snapshot.cursor, 1);
    expect(snapshot.tail, isNotEmpty);

    // "chiusura e riapertura": i byte salvati sono la revisione corrente
    final saved = Uint8List.fromList(first.bytes);
    final second = open(saved);
    expect(second.canUndo, isFalse);
    expect(second.canRedo, isFalse);

    expect(second.restoreHistory(snapshot), isTrue);
    expect(second.canUndo, isTrue);
    expect(second.canRedo, isTrue);
    expect(second.revisionCount, 3);
    expect(second.bytes.length, saved.length);

    // ripeti porta alla stessa revisione che aveva la prima sessione
    final firstRedo = first..redo();
    second.redo();
    expect(second.bytes.length, firstRedo.bytes.length);
    expect(second.canRedo, isFalse);

    // e annulla due volte torna al documento com'era all'apertura
    second.undo();
    second.undo();
    expect(second.canUndo, isFalse);
    expect(second.bytes.length, snapshot.revisions.first);
  });

  test('una nuova modifica dopo il ripristino scarta la parte da ripetere',
      () {
    final first = open(buildMultiPagePdf(1));
    first.placeCheckMark(0, 100, 100);
    first.placeCheckMark(0, 200, 200);
    first.undo();
    final snapshot = first.historySnapshot!;
    final second = open(Uint8List.fromList(first.bytes));
    expect(second.restoreHistory(snapshot), isTrue);

    second.placeCheckMark(0, 300, 300);
    expect(second.canRedo, isFalse);
    expect(second.revisionCount, 3);
    expect(second.canUndo, isTrue);
  });

  test('byte diversi o sessione gia modificata: non cambia niente', () {
    final first = open(buildMultiPagePdf(1));
    first.placeCheckMark(0, 100, 100);
    final snapshot = first.historySnapshot!;

    // un documento diverso non accetta la cronologia
    final other = open(buildMultiPagePdf(2));
    expect(other.restoreHistory(snapshot), isFalse);
    expect(other.canUndo, isFalse);

    // una sessione con modifiche gia fatte non viene toccata
    final edited = open(Uint8List.fromList(first.bytes));
    edited.placeCheckMark(0, 50, 50);
    final before = edited.revisionCount;
    expect(edited.restoreHistory(snapshot), isFalse);
    expect(edited.revisionCount, before);
  });
}
