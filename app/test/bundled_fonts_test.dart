// I dieci font gratuiti del menu, con il font imitato tra parentesi:
// ci sono tutti, si leggono dal pacchetto, si incorporano nel PDF e il font di
// riserva del testo composto (DejaVu) si trova ancora dopo la rinomina.
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:dart_pdf_editor_assets/dart_pdf_editor_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_document/pdf_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tenLabels = <String>[
    'Carlito (Calibri)',
    'Arimo (Arial)',
    'Tinos (Times New Roman)',
    'Cousine (Courier New)',
    'Caladea (Cambria)',
    'Gelasio (Georgia)',
    'DejaVu Sans (Verdana)',
    'Open Sans (Segoe UI)',
    'Comic Neue (Comic Sans)',
    'EB Garamond (Garamond)',
  ];

  test('il menu ha i dieci font, in testa, con il font imitato tra parentesi',
      () {
    final labels = bundledEditorFonts.map((f) => f.label).toList();
    expect(labels.take(10).toList(), tenLabels);
    for (final label in tenLabels) {
      expect(label, contains('('));
      expect(label, endsWith(')'));
    }
    // quelli che c'erano restano
    for (final old in [
      'DejaVu Serif',
      'DejaVu Sans Mono',
      'Fira Sans',
      'Spectral',
      'Lobster',
    ]) {
      expect(labels, contains(old));
    }
    // nessun nome ripetuto
    expect(labels.toSet().length, labels.length);
  });

  test('ci sono anche i quaranta font piu\' comuni, senza nomi ripetuti', () {
    const forty = <String>[
      'Roboto',
      'Lato',
      'Montserrat',
      'Poppins',
      'Noto Sans',
      'Source Sans 3',
      'Nunito',
      'Ubuntu',
      'Inter',
      'Work Sans',
      'Raleway',
      'Oswald',
      'PT Sans',
      'Rubik',
      'Quicksand',
      'Mulish',
      'Karla',
      'Cabin',
      'Titillium Web',
      'Josefin Sans',
      'Barlow',
      'IBM Plex Sans',
      'DM Sans',
      'Roboto Condensed',
      'Merriweather',
      'Playfair Display',
      'Lora',
      'PT Serif',
      'Noto Serif',
      'Source Serif 4',
      'Libre Baskerville',
      'Crimson Text',
      'Roboto Slab',
      'Cormorant Garamond',
      'Bitter',
      'Source Code Pro',
      'Roboto Mono',
      'IBM Plex Mono',
      'Bebas Neue',
      'Dancing Script',
    ];
    final labels = bundledEditorFonts.map((f) => f.label).toList();
    expect(forty.length, 40);
    for (final name in forty) {
      expect(labels, contains(name));
    }
    expect(bundledEditorFonts.length, 55);
  });

  test('ogni font si legge dal pacchetto e si incorpora', () async {
    for (final font in bundledEditorFonts) {
      final bytes = await loadBundledFont(font);
      expect(bytes.length, greaterThan(10000), reason: font.label);
      // se il file non fosse un font valido qui darebbe errore
      expect(() => PdfEmbeddedFont.parse(bytes), returnsNormally,
          reason: font.label);
    }
  });

  test('il font di riserva del testo composto trova ancora DejaVu', () async {
    pdfBundledFonts = bundledEditorFonts;
    final fonts = await loadFallbackFonts();
    expect(fonts.length, 3);
  });
}
