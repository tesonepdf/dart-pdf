import 'package:dart_pdf_editor_app/file_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le barre di una data restano, con un carattere gemello', () {
    expect(safeFileName('contratto 14/11/2026'),
        'contratto 14\u221511\u22152026');
    expect(safeFileName(r'14\11\2026'), '14\uFF3C11\uFF3C2026');
    expect(safeFileName('14/11/2026').contains('/'), isFalse);
  });

  test('caratteri non ammessi e spazi in eccesso', () {
    expect(safeFileName('a:b*c?d'), 'a-b-c-d');
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
