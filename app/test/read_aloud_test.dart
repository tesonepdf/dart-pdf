import 'package:dart_pdf_editor_app/read_aloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short text stays in one block', () {
    expect(ReadAloud.chunks('Ciao a tutti.'), ['Ciao a tutti.']);
  });

  test('empty or blank text gives no blocks', () {
    expect(ReadAloud.chunks(''), isEmpty);
    expect(ReadAloud.chunks('  \n \r\n '), isEmpty);
  });

  test('long text is cut at a sentence end, every block within the limit', () {
    final sentence = 'Questa è una frase di prova lunga abbastanza. ';
    final text = sentence * 200; // circa 9000 caratteri
    final parts = ReadAloud.chunks(text);
    expect(parts.length, greaterThan(1));
    for (final part in parts) {
      expect(part.length, lessThanOrEqualTo(3000));
      expect(part.endsWith('.'), isTrue);
    }
    // niente testo perso: stesse parole, stesso ordine
    expect(parts.join(' ').replaceAll(RegExp(r'\s+'), ' '),
        text.trim().replaceAll(RegExp(r'\s+'), ' '));
  });

  test('text with no punctuation is cut at a space', () {
    final text = List.filled(1500, 'parola').join(' '); // circa 10000
    final parts = ReadAloud.chunks(text);
    expect(parts.length, greaterThan(1));
    for (final part in parts) {
      expect(part.length, lessThanOrEqualTo(3000));
      expect(part.startsWith('parola'), isTrue);
      expect(part.endsWith('parola'), isTrue);
    }
  });

  test('language tags follow the app language', () {
    expect(readAloudLanguageTag('it'), 'it-IT');
    expect(readAloudLanguageTag('en'), 'en-US');
    expect(readAloudLanguageTag('ja'), 'ja');
    expect(readAloudLabels('it').read, 'Leggi ad alta voce');
    expect(readAloudLabels('en').read, 'Read aloud');
  });
}
