import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'standard_sizes.dart';

/// La misura reale con cui le foto aperte diventano PDF (Impostazioni ->
/// "Misura delle foto"). Null = come prima: la foto riempie la larghezza
/// di un foglio A4.
class PhotoSizeSetting extends ValueNotifier<String?> {
  PhotoSizeSetting() : super(null);

  static final PhotoSizeSetting instance = PhotoSizeSetting();

  static const _key = 'dart_pdf_editor_app.photo.size';

  Future<void>? _loading;

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_key);
    } catch (error) {
      debugPrint('Misura foto non leggibile: $error');
    }
  }

  Future<void> save(String? id) async {
    value = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, id);
      }
    } catch (error) {
      debugPrint('Misura foto non salvata: $error');
    }
  }

  StandardSize? get size => value == null ? null : standardSizeById(value!);
}

/// Il blocco delle Impostazioni: "Automatica" più un menu espandibile per
/// ogni argomento (carte, foto tessera, fogli...), con le misure dentro.
class PhotoSizeSettingsSection extends StatefulWidget {
  const PhotoSizeSettingsSection({super.key, required this.setting});

  final PhotoSizeSetting setting;

  @override
  State<PhotoSizeSettingsSection> createState() =>
      _PhotoSizeSettingsSectionState();
}

class _PhotoSizeSettingsSectionState extends State<PhotoSizeSettingsSection> {
  @override
  void initState() {
    super.initState();
    widget.setting.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.setting,
      builder: (context, selected, _) {
        Widget option(String? id, String title, String? subtitle) =>
            RadioListTile<String?>(
              key: ValueKey('settings-photo-size-${id ?? 'auto'}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: id,
              title: Text(title),
              subtitle: subtitle == null ? null : Text(subtitle),
            );
        return RadioGroup<String?>(
          groupValue: selected,
          onChanged: (id) => widget.setting.save(id),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quando apri una foto, diventa un PDF della grandezza '
                'reale scelta qui.'),
            option(null, 'Automatica',
                'La foto riempie la larghezza di un foglio A4'),
            for (final group in StandardSizeGroup.values)
              if (standardSizesIn(group).isNotEmpty)
                ExpansionTile(
                  key: ValueKey('settings-photo-size-group-${group.name}'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(left: 8),
                  initiallyExpanded:
                      standardSizesIn(group).any((s) => s.id == selected),
                  title: Text(group.label),
                  children: [
                    for (final s in standardSizesIn(group))
                      option(
                        s.id,
                        s.name,
                        '${_mm(s.widthMm)} x ${_mm(s.heightMm)} mm'
                        '${s.note == null ? '' : ' - ${s.note}'}',
                      ),
                  ],
                ),
          ],
          ),
        );
      },
    );
  }
}

String _mm(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
