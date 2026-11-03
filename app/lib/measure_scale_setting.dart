import 'dart:async';

import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfEditingPreferences, PdfMeasurementScale;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La scala dello strumento Misura: "Automatica" (1 cm sul foglio = 1 cm
/// reale, in base alla misura vera del foglio) oppure "Personalizzata" (la
/// scelta nello strumento Misura). Vale true per Automatica.
class MeasureScaleSetting extends ValueNotifier<bool> {
  MeasureScaleSetting() : super(true);

  static final MeasureScaleSetting instance = MeasureScaleSetting();

  static const _key = 'dart_pdf_editor_app.measure.auto';

  /// Un PDF conta in punti (1/72 di pollice): 1 punto = 2,54 / 72 cm reali.
  static const PdfMeasurementScale autoScale = PdfMeasurementScale(
    unitsPerPoint: 2.54 / 72,
    unitLabel: 'cm',
    pageUnitLabel: 'cm',
  );

  Future<void>? _loading;

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(_key) ?? true;
    } catch (error) {
      debugPrint('Scala di misura non leggibile: $error');
    }
  }

  Future<void> save(bool auto) async {
    value = auto;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, auto);
    } catch (error) {
      debugPrint('Scala di misura non salvata: $error');
    }
  }
}

/// Il blocco delle Impostazioni: Automatica o Personalizzata.
class MeasureScaleSettingsSection extends StatelessWidget {
  const MeasureScaleSettingsSection({super.key, required this.prefs});

  final PdfEditingPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final setting = MeasureScaleSetting.instance;
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: setting,
      builder: (context, auto, _) {
        Widget option(bool isAuto, String title, String subtitle) => ListTile(
              key: ValueKey('settings-measure-scale-${isAuto ? 'auto' : 'custom'}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(auto == isAuto
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(title),
              subtitle: Text(subtitle),
              onTap: () {
                unawaited(setting.save(isAuto));
                if (isAuto) prefs.measurementScale = MeasureScaleSetting.autoScale;
              },
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scala della misura', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            option(
              true,
              'Automatica',
              'In base alla misura del foglio: 1 cm sul foglio = 1 cm reale. '
                  'Va da un punto A a un punto B e ti dice i mm veri.',
            ),
            option(
              false,
              'Personalizzata',
              'La scala la scegli tu nello strumento Misura (per disegni in scala).',
            ),
          ],
        );
      },
    );
  }
}
