import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dialog.dart';

/// I passi scelti dall'utente per i pulsanti meno e più, uno per ogni valore
/// (Opacità, Dimensione carattere, ...), salvati sul dispositivo.
class PdfStepStore {
  PdfStepStore._();

  static final PdfStepStore instance = PdfStepStore._();

  static const _prefix = 'dart_pdf_editor.step.';

  final Map<String, double> _steps = {};
  bool _loaded = false;

  /// Carica i passi salvati (una volta sola).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_prefix)) continue;
        final value = prefs.getDouble(key);
        if (value != null && value > 0) {
          _steps.putIfAbsent(key.substring(_prefix.length), () => value);
        }
      }
    } catch (_) {
      // Senza archivio restano i passi predefiniti.
    }
  }

  double? stepFor(String id) => _steps[id];

  Future<void> setStep(String id, double step) async {
    _steps[id] = step;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_prefix$id', step);
    } catch (_) {}
  }
}

/// Il passo predefinito di un valore, preso dalla sua scala: circa un
/// ventesimo, arrotondato a un numero comodo.
double pdfDefaultStep(double min, double max) {
  final target = (max - min) / 20;
  const nice = [0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0];
  var best = nice.first;
  for (final n in nice) {
    if ((n - target).abs() < (best - target).abs()) best = n;
  }
  return best;
}

/// Meno, più e ingranaggio: al posto della barra, per cambiare un valore di un
/// passo alla volta anche dal telefono. L'ingranaggio apre un piccolo
/// riquadro dove l'utente scrive di quanto cambia ogni tocco; il passo si
/// salva per [stepId].
class PdfStepButtons extends StatefulWidget {
  const PdfStepButtons({
    super.key,
    required this.stepId,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onStep,
    required this.valueField,
    this.enabled = true,
  });

  /// Identificativo per salvare il passo (per esempio `opacity`).
  final String stepId;

  /// Nome del valore, mostrato nel riquadro dell'ingranaggio.
  final String title;
  final double value;

  /// Estremi tra cui il valore può muoversi con meno e più.
  final double min;
  final double max;

  /// Come si scrive il valore (per esempio `100%` o `2.0 pt`).
  final String Function(double) display;

  /// Chiamata con il nuovo valore dopo ogni tocco su meno o più.
  final ValueChanged<double> onStep;

  /// Il campo del numero (scrivibile), tra il più e l'ingranaggio.
  final Widget valueField;
  final bool enabled;

  @override
  State<PdfStepButtons> createState() => _PdfStepButtonsState();
}

class _PdfStepButtonsState extends State<PdfStepButtons> {
  late double _step;

  @override
  void initState() {
    super.initState();
    _step = PdfStepStore.instance.stepFor(widget.stepId) ??
        pdfDefaultStep(widget.min, widget.max);
    PdfStepStore.instance.load().then((_) {
      final saved = PdfStepStore.instance.stepFor(widget.stepId);
      if (mounted && saved != null && saved != _step) {
        setState(() => _step = saved);
      }
    });
  }

  void _apply(double direction) {
    final raw = widget.value + direction * _step;
    final next = double.parse(raw.toStringAsFixed(4))
        .clamp(widget.min, widget.max)
        .toDouble();
    if (next != widget.value) widget.onStep(next);
  }

  static String _unitOf(String shown) =>
      shown.replaceFirst(RegExp(r'^[\s\d.,\-+]+'), '').trim();

  static String _fmt(double v) {
    final s = v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }

  Future<void> _editStep() async {
    final unit = _unitOf(widget.display(widget.value));
    final controller =
        TextEditingController(text: _fmt(_step).replaceAll('.', ','));
    final picked = await showPdfDialog<double>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          final parsed =
              double.tryParse(controller.text.trim().replaceAll(',', '.'));
          if (parsed != null && parsed > 0) {
            Navigator.of(dialogContext).pop(parsed);
          }
        }

        final scheme = Theme.of(dialogContext).colorScheme;
        final size = MediaQuery.sizeOf(dialogContext);
        final width = (size.width * 0.52).clamp(220.0, 300.0).toDouble();
        // il riquadro sta sempre in alto a sinistra, qualunque riga si tocchi
        final top = MediaQuery.paddingOf(dialogContext).top + 16;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, top, 12, 12),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Material(
                key: const ValueKey('pdf-step-dialog'),
                color: scheme.surfaceContainerHigh,
                elevation: 6,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: Theme.of(dialogContext).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('Valore adesso: ${widget.display(widget.value)}',
                          style: Theme.of(dialogContext).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      const Text('Cambia a ogni tocco di:'),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('pdf-step-field'),
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixText: unit.isEmpty ? null : unit,
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            key: const ValueKey('pdf-step-ok'),
                            onPressed: submit,
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (picked == null) return;
    await PdfStepStore.instance.setStep(widget.stepId, picked);
    if (mounted) setState(() => _step = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDown = widget.enabled && widget.value > widget.min;
    final canUp = widget.enabled && widget.value < widget.max;
    final base = widget.stepId;
    Widget circle(String key, IconData icon, bool enabled, VoidCallback tap) =>
        SizedBox(
          width: 34,
          height: 34,
          child: IconButton(
            key: ValueKey('$base-$key'),
            padding: EdgeInsets.zero,
            iconSize: 20,
            style: IconButton.styleFrom(
              side: BorderSide(
                  color: enabled ? scheme.outline : scheme.outlineVariant),
              shape: const CircleBorder(),
            ),
            icon: Icon(icon, color: enabled ? scheme.primary : null),
            onPressed: enabled ? tap : null,
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      circle('minus', Icons.remove, canDown, () => _apply(-1)),
      const SizedBox(width: 6),
      circle('plus', Icons.add, canUp, () => _apply(1)),
      const SizedBox(width: 6),
      widget.valueField,
      // l'ingranaggio sta un po' piu' staccato di meno e piu'
      const SizedBox(width: 10),
      IconButton(
        key: ValueKey('${widget.stepId}-step-settings'),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        icon: const Icon(Icons.settings, size: 20),
        onPressed: widget.enabled ? _editStep : null,
      ),
    ]);
  }
}
