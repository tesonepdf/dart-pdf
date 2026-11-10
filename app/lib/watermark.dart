import 'dart:math' as math;

import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfDialogSubmit, showPdfDialog;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:material_ui/material_ui.dart';
import 'package:pdf_document/pdf_document.dart';

import 'l10n/app_l10n.dart';

// Filigrana: scrive un testo grande, anche inclinato, al centro delle pagine,
// su tutte o da una pagina in poi. Si usa `PdfContentEditing.stampPage` e
// `PdfStamp.text` del motore (Helvetica grassetto). Il motore non ha la
// trasparenza: l'intensità è un grigio più o meno chiaro, e la scritta sta
// sopra al contenuto della pagina.

/// Grandezza del testo.
enum WatermarkSize {
  small('Piccola', 24),
  medium('Media', 48),
  large('Grande', 72);

  const WatermarkSize(this.label, this.points);

  final String label;
  final double points;
}

/// Inclinazione del testo.
enum WatermarkAngle {
  flat('Dritta', 0),
  diagonal('Diagonale', 45),
  vertical('Verticale', 90);

  const WatermarkAngle(this.label, this.degrees);

  final String label;
  final double degrees;
}

/// Quanto si vede la scritta (grigio 0xRRGGBB).
enum WatermarkStrength {
  light('Chiara', 0xD0D0D0),
  medium('Media', 0xB0B0B0),
  strong('Forte', 0x808080);

  const WatermarkStrength(this.label, this.color);

  final String label;
  final int color;
}

/// Le scelte per la filigrana.
class WatermarkOptions {
  const WatermarkOptions({
    this.text = 'BOZZA',
    this.size = WatermarkSize.medium,
    this.angle = WatermarkAngle.diagonal,
    this.strength = WatermarkStrength.medium,
    this.firstPage = 1,
  });

  final String text;
  final WatermarkSize size;
  final WatermarkAngle angle;
  final WatermarkStrength strength;

  /// La prima pagina da marcare, da 1.
  final int firstPage;
}

/// Scrive la filigrana nel documento di [editor], dalla pagina
/// `options.firstPage` (da 1) all'ultima. Senza testo, o con una prima pagina
/// oltre la fine, non scrive niente.
void applyWatermark(PdfEditor editor, WatermarkOptions options) {
  final count = editor.document.pageCount;
  final text = options.text.trim();
  if (count == 0 || text.isEmpty || options.firstPage > count) return;
  final size = options.size.points;
  final r = options.angle.degrees * math.pi / 180;
  // Mezza altezza delle maiuscole, per centrare anche in verticale.
  final half = size * 0.35;
  for (var i = (options.firstPage - 1).clamp(0, count - 1); i < count; i++) {
    editor.stampPage(i, (stamp) {
      final box = stamp.page.cropBox;
      final width = stamp.measureText(text, size: size, bold: true);
      final cx = box.left + box.width / 2;
      final cy = box.bottom + box.height / 2;
      stamp.text(
        text,
        x: cx - (width / 2) * math.cos(r) + half * math.sin(r),
        y: cy - (width / 2) * math.sin(r) - half * math.cos(r),
        size: size,
        color: options.strength.color,
        bold: true,
        angleDegrees: options.angle.degrees,
      );
    });
  }
}

/// Chiede come mettere la filigrana su un documento di [pageCount] pagine.
/// Restituisce null se si annulla.
Future<WatermarkOptions?> showWatermarkDialog(BuildContext context,
    {required int pageCount}) {
  var size = WatermarkSize.medium;
  var angle = WatermarkAngle.diagonal;
  var strength = WatermarkStrength.medium;
  final textController = TextEditingController(text: 'BOZZA');
  final firstController = TextEditingController(text: '1');
  return showPdfDialog<WatermarkOptions>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        int firstPage() {
          final n = int.tryParse(firstController.text.trim()) ?? 1;
          return n.clamp(1, pageCount < 1 ? 1 : pageCount);
        }

        bool canConfirm() => textController.text.trim().isNotEmpty;

        void confirm() {
          if (!canConfirm()) return;
          Navigator.of(context).pop(WatermarkOptions(
            text: textController.text.trim(),
            size: size,
            angle: angle,
            strength: strength,
            firstPage: firstPage(),
          ));
        }

        return AlertDialog(
          key: const ValueKey('watermark-dialog'),
          title: const Text('Filigrana'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('watermark-text'),
                    controller: textController,
                    decoration: const InputDecoration(labelText: 'Testo'),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => confirm(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Grandezza'),
                  const SizedBox(height: 8),
                  SegmentedButton<WatermarkSize>(
                    key: const ValueKey('watermark-size'),
                    showSelectedIcon: false,
                    segments: [
                      for (final s in WatermarkSize.values)
                        ButtonSegment(value: s, label: Text(s.label)),
                    ],
                    selected: {size},
                    onSelectionChanged: (s) => setState(() => size = s.first),
                  ),
                  const SizedBox(height: 12),
                  const Text('Inclinazione'),
                  const SizedBox(height: 8),
                  SegmentedButton<WatermarkAngle>(
                    key: const ValueKey('watermark-angle'),
                    showSelectedIcon: false,
                    segments: [
                      for (final a in WatermarkAngle.values)
                        ButtonSegment(value: a, label: Text(a.label)),
                    ],
                    selected: {angle},
                    onSelectionChanged: (s) => setState(() => angle = s.first),
                  ),
                  const SizedBox(height: 12),
                  const Text('Intensità'),
                  const SizedBox(height: 8),
                  SegmentedButton<WatermarkStrength>(
                    key: const ValueKey('watermark-strength'),
                    showSelectedIcon: false,
                    segments: [
                      for (final s in WatermarkStrength.values)
                        ButtonSegment(value: s, label: Text(s.label)),
                    ],
                    selected: {strength},
                    onSelectionChanged: (s) =>
                        setState(() => strength = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('watermark-first'),
                    controller: firstController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Dalla pagina (di $pageCount)',
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
                key: const ValueKey('watermark-confirm'),
                onPressed: canConfirm() ? confirm : null,
                child: const Text('Applica'),
              ),
            ),
          ],
        );
      },
    ),
  );
}
