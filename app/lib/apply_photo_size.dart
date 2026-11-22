import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:material_ui/material_ui.dart';
import 'package:pdf_document/pdf_document.dart' show PdfRect;

import 'standard_sizes.dart';

// "Applica misura": porta una foto gia' messa sulla pagina a una misura reale
// (carta d'identita', 10 x 15, 13 x 18, o una misura qualsiasi). Serve quando
// la foto non ha un riferimento di misura: la misura gliela dai tu.

/// La misura scelta nella finestra.
class PhotoSizeChoice {
  const PhotoSizeChoice({
    required this.widthMm,
    required this.heightMm,
    required this.keepProportions,
  });

  /// Larghezza e altezza della misura, in millimetri. L'orientamento non
  /// conta: si gira da sola per seguire quello della foto.
  final double widthMm;
  final double heightMm;

  /// True: la foto entra nella misura senza deformarsi (tocca la larghezza o
  /// l'altezza). False: la foto prende esattamente la misura, anche se si
  /// deforma.
  final bool keepProportions;
}

/// Il nuovo rettangolo della foto sulla pagina, con lo stesso centro di
/// prima. [current] e' il rettangolo nello spazio della pagina; con una
/// pagina ruotata di 90 o 270 gradi larghezza e altezza viste a schermo sono
/// scambiate rispetto a quelle del rettangolo.
PdfRect resizedPhotoRect({
  required PdfRect current,
  required int pageRotation,
  required PhotoSizeChoice choice,
}) {
  final turned = pageRotation % 180 != 0;
  final visualW = turned ? current.height : current.width;
  final visualH = turned ? current.width : current.height;
  var boxW = mmToPoints(choice.widthMm);
  var boxH = mmToPoints(choice.heightMm);
  // la misura segue l'orientamento della foto: una foto in orizzontale su una
  // misura 10 x 15 diventa 15 x 10
  if ((boxW >= boxH) != (visualW >= visualH)) {
    final t = boxW;
    boxW = boxH;
    boxH = t;
  }
  var newW = boxW;
  var newH = boxH;
  if (choice.keepProportions && visualW > 0 && visualH > 0) {
    final scale = boxW / visualW < boxH / visualH ? boxW / visualW : boxH / visualH;
    newW = visualW * scale;
    newH = visualH * scale;
  }
  final pageW = turned ? newH : newW;
  final pageH = turned ? newW : newH;
  final cx = (current.left + current.right) / 2;
  final cy = (current.bottom + current.top) / 2;
  return PdfRect(cx - pageW / 2, cy - pageH / 2, cx + pageW / 2, cy + pageH / 2);
}

String _mm(double v) {
  final s = v.toStringAsFixed(1);
  return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s)
      .replaceAll('.', ',');
}

/// Le misure che servono piu' spesso, in cima alla finestra.
const List<String> _kQuickSizes = [
  'card_cie',
  'print_10x15',
  'print_13x18',
  'a4',
];

/// La finestra "Applica misura". Null se si annulla. [pickStandard] apre
/// l'elenco completo delle misure e restituisce l'id scelto.
Future<PhotoSizeChoice?> showApplyPhotoSizeDialog(
  BuildContext context, {
  double? currentWidthMm,
  double? currentHeightMm,
  required Future<String?> Function() pickStandard,
  String title = 'Applica misura',
  bool allowExact = true,
}) {
  return showDialog<PhotoSizeChoice>(
    context: context,
    builder: (context) => _ApplyPhotoSizeDialog(
      currentWidthMm: currentWidthMm,
      currentHeightMm: currentHeightMm,
      pickStandard: pickStandard,
      title: title,
      allowExact: allowExact,
    ),
  );
}

class _ApplyPhotoSizeDialog extends StatefulWidget {
  const _ApplyPhotoSizeDialog({
    required this.currentWidthMm,
    required this.currentHeightMm,
    required this.pickStandard,
    required this.title,
    required this.allowExact,
  });

  final double? currentWidthMm;
  final double? currentHeightMm;
  final Future<String?> Function() pickStandard;
  final String title;

  /// Se offrire "Misura esatta" (deforma la foto). Senza, la foto entra
  /// sempre nella misura mantenendo le proporzioni.
  final bool allowExact;

  @override
  State<_ApplyPhotoSizeDialog> createState() => _ApplyPhotoSizeDialogState();
}

class _ApplyPhotoSizeDialogState extends State<_ApplyPhotoSizeDialog> {
  final _width = TextEditingController();
  final _height = TextEditingController();
  bool _keep = true;
  bool _cm = true;
  String? _error;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  void _pop(double widthMm, double heightMm) => Navigator.of(context).pop(
        PhotoSizeChoice(
            widthMm: widthMm, heightMm: heightMm, keepProportions: _keep),
      );

  void _applyCustom() {
    double? parse(String text) =>
        double.tryParse(text.trim().replaceAll(',', '.'));
    final w = parse(_width.text);
    final h = parse(_height.text);
    if (w == null || h == null || w <= 0 || h <= 0) {
      setState(() => _error = 'Scrivi larghezza e altezza.');
      return;
    }
    final factor = _cm ? 10.0 : 1.0;
    final wMm = w * factor;
    final hMm = h * factor;
    if (wMm < 1 || hMm < 1 || wMm > 5000 || hMm > 5000) {
      setState(() => _error = 'Misura fuori dai limiti (da 1 mm a 5 m).');
      return;
    }
    _pop(wMm, hMm);
  }

  Future<void> _all() async {
    final id = await widget.pickStandard();
    if (id == null || !mounted) return;
    final size = standardSizeById(id);
    if (size != null) _pop(size.widthMm, size.heightMm);
  }

  @override
  Widget build(BuildContext context) {
    final quick = [
      ...kCustomSizes,
      for (final id in _kQuickSizes)
        if (standardSizeById(id) case final size?) size,
    ];
    return AlertDialog(
      key: const ValueKey('apply-size-dialog'),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.currentWidthMm != null && widget.currentHeightMm != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Misura attuale: ${_mm(widget.currentWidthMm!)} × '
                    '${_mm(widget.currentHeightMm!)} mm'),
              ),
            if (widget.allowExact) ...[
              SegmentedButton<bool>(
                key: const ValueKey('apply-size-keep'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('Stesse proporzioni')),
                  ButtonSegment(value: false, label: Text('Misura esatta')),
                ],
                selected: {_keep},
                onSelectionChanged: (s) => setState(() => _keep = s.first),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  _keep
                      ? 'La foto entra nella misura senza deformarsi.'
                      : 'La foto prende esattamente la misura, anche deformandosi.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'La foto entra nella misura senza deformarsi e la pagina si rifà a grandezza vera.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (final size in quick)
              ListTile(
                key: ValueKey('apply-size-${size.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(size.name),
                subtitle: Text('${_mm(size.widthMm)} × ${_mm(size.heightMm)} mm'),
                onTap: () => _pop(size.widthMm, size.heightMm),
              ),
            ListTile(
              key: const ValueKey('apply-size-all'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.list),
              title: const Text('Tutte le misure…'),
              onTap: _all,
            ),
            const Divider(),
            Text('Misura personalizzata',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('apply-size-width'),
                    controller: _width,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Larghezza'),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('×'),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('apply-size-height'),
                    controller: _height,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(labelText: 'Altezza'),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: const ValueKey('apply-size-unit'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('cm')),
                ButtonSegment(value: false, label: Text('mm')),
              ],
              selected: {_cm},
              onSelectionChanged: (s) => setState(() => _cm = s.first),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('apply-size-custom'),
          onPressed: _applyCustom,
          child: const Text('Applica'),
        ),
      ],
    );
  }
}
