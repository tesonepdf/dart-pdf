import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfDialogSubmit, showPdfDialog;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:material_ui/material_ui.dart';
import 'package:pdf_document/pdf_document.dart';

import 'l10n/app_l10n.dart';

// Numera le pagine: scrive il numero in un angolo o al centro, in alto o in
// basso, su tutte le pagine o da una pagina in poi. Il testo si scrive con
// `PdfEditor.stampHeaderFooter` del motore (Helvetica, come intestazioni e
// piè di pagina). Qui ci sono le scelte, la finestra e il collegamento al
// motore; il collegamento al menu è in `editor_screen.dart`.

/// Dove va il numero sulla pagina.
enum PageNumberPosition {
  bottomCenter('In basso al centro'),
  bottomRight('In basso a destra'),
  bottomLeft('In basso a sinistra'),
  topCenter('In alto al centro'),
  topRight('In alto a destra'),
  topLeft('In alto a sinistra');

  const PageNumberPosition(this.label);

  final String label;

  bool get isTop =>
      this == topCenter || this == topRight || this == topLeft;
}

/// Come si scrive il numero. `{page}` è il numero della pagina, `{pages}` il
/// totale delle pagine.
enum PageNumberFormat {
  pageOfPages('Pagina 1 di 5', 'Pagina {page} di {pages}'),
  pageWord('Pagina 1', 'Pagina {page}'),
  slash('1 / 5', '{page} / {pages}'),
  plain('1', '{page}');

  const PageNumberFormat(this.label, this.template);

  final String label;
  final String template;
}

/// Le scelte per numerare le pagine.
class PageNumberOptions {
  const PageNumberOptions({
    this.position = PageNumberPosition.bottomCenter,
    this.format = PageNumberFormat.pageOfPages,
    this.size = 10,
    this.firstPage = 1,
  });

  final PageNumberPosition position;
  final PageNumberFormat format;

  /// Corpo del carattere in punti.
  final double size;

  /// La prima pagina da numerare, da 1. Il numero scritto è sempre quello
  /// vero della pagina: partire dalla 3 lascia le prime due senza numero e la
  /// terza dice 3.
  final int firstPage;
}

/// Il testo di una fascia (a sinistra, al centro o a destra) per [options].
PdfHeaderFooter pageNumberBand(PageNumberOptions options) {
  final text = options.format.template;
  return switch (options.position) {
    PageNumberPosition.bottomLeft ||
    PageNumberPosition.topLeft =>
      PdfHeaderFooter(left: text, size: options.size, margin: 28),
    PageNumberPosition.bottomRight ||
    PageNumberPosition.topRight =>
      PdfHeaderFooter(right: text, size: options.size, margin: 28),
    PageNumberPosition.bottomCenter ||
    PageNumberPosition.topCenter =>
      PdfHeaderFooter(center: text, size: options.size, margin: 28),
  };
}

/// Scrive i numeri di pagina nel documento di [editor], dalla pagina
/// `options.firstPage` (da 1) all'ultima. Una prima pagina oltre la fine non
/// numera niente.
void applyPageNumbers(PdfEditor editor, PageNumberOptions options) {
  final count = editor.document.pageCount;
  if (count == 0 || options.firstPage > count) return;
  final band = pageNumberBand(options);
  editor.stampHeaderFooter(
    header: options.position.isTop ? band : null,
    footer: options.position.isTop ? null : band,
    fromPage: (options.firstPage - 1).clamp(0, count - 1),
  );
}

/// Chiede come numerare le pagine di un documento di [pageCount] pagine.
/// Restituisce null se si annulla.
Future<PageNumberOptions?> showPageNumbersDialog(BuildContext context,
    {required int pageCount}) {
  var position = PageNumberPosition.bottomCenter;
  var format = PageNumberFormat.pageOfPages;
  var size = 10.0;
  final firstController = TextEditingController(text: '1');
  return showPdfDialog<PageNumberOptions>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        int firstPage() {
          final n = int.tryParse(firstController.text.trim()) ?? 1;
          return n.clamp(1, pageCount < 1 ? 1 : pageCount);
        }

        void confirm() => Navigator.of(context).pop(PageNumberOptions(
              position: position,
              format: format,
              size: size,
              firstPage: firstPage(),
            ));

        return AlertDialog(
          key: const ValueKey('page-numbers-dialog'),
          title: const Text('Numera le pagine'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Posizione'),
                  DropdownButton<PageNumberPosition>(
                    key: const ValueKey('page-numbers-position'),
                    isExpanded: true,
                    value: position,
                    items: [
                      for (final p in PageNumberPosition.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (p) => setState(() => position = p ?? position),
                  ),
                  const SizedBox(height: 12),
                  const Text('Come si scrive'),
                  DropdownButton<PageNumberFormat>(
                    key: const ValueKey('page-numbers-format'),
                    isExpanded: true,
                    value: format,
                    items: [
                      for (final f in PageNumberFormat.values)
                        DropdownMenuItem(value: f, child: Text(f.label)),
                    ],
                    onChanged: (f) => setState(() => format = f ?? format),
                  ),
                  const SizedBox(height: 12),
                  const Text('Grandezza'),
                  const SizedBox(height: 8),
                  SegmentedButton<double>(
                    key: const ValueKey('page-numbers-size'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 8, label: Text('Piccola')),
                      ButtonSegment(value: 10, label: Text('Media')),
                      ButtonSegment(value: 14, label: Text('Grande')),
                    ],
                    selected: {size},
                    onSelectionChanged: (s) => setState(() => size = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('page-numbers-first'),
                    controller: firstController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Dalla pagina (di $pageCount)',
                      helperText: 'Il numero scritto è quello vero della '
                          'pagina.',
                    ),
                    onSubmitted: (_) => confirm(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(appL10n(context).cancel),
            ),
            PdfDialogSubmit.action(
              onSubmit: confirm,
              child: FilledButton(
                key: const ValueKey('page-numbers-confirm'),
                onPressed: confirm,
                child: const Text('Numera'),
              ),
            ),
          ],
        );
      },
    ),
  );
}
