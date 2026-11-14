import 'package:dart_pdf_editor_app/file_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le barre di una data non riducono il nome a "2026"', () {
    expect(safeFileName('contratto 14/11/2026'), 'contratto 14-11-2026');
    expect(safeFileName('14/11/2026'), '14-11-2026');
  });

  test('caratteri non ammessi e spazi in eccesso', () {
    expect(safeFileName(r'a\b:c*d?e'), 'a-b-c-d-e');
    expect(safeFileName('  file   letto.pdf '), 'file letto.pdf');
    expect(safeFileName('   '), '');
  });

  test('il salvataggio in cartella riporta il nome scritto', () {
    final result = SaveResult.savedInFolder('Documenti', 'file letto.pdf');
    expect(result.succeeded, isTrue);
    expect(result.savedName, 'file letto.pdf');
    expect(result.path, isNull);
  });
}
