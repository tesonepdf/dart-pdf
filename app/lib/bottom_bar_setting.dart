import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La scelta "Barra in basso" (Home, Crea, File, Strumenti, Impostazioni),
/// salvata sul dispositivo. Spenta di base: l'app resta com'e' finche' non si
/// accende da Impostazioni.
///
/// Un'unica istanza serve tutte le finestre ([instance]): se si cambia in una,
/// vale per tutte.
class BottomBarSetting extends ValueNotifier<bool> {
  BottomBarSetting() : super(false);

  /// La scelta dell'app. Va letta una volta all'avvio con [load].
  static final BottomBarSetting instance = BottomBarSetting();

  static const _key = 'dart_pdf_editor_app.bottom_bar';

  Future<void>? _loading;
  bool _chosen = false;

  /// Legge la scelta salvata. Si puo' chiamare piu' volte: aspettano tutte la
  /// stessa lettura.
  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // una scelta fatta mentre si leggeva vince su quella salvata
      if (!_chosen) value = prefs.getBool(_key) ?? false;
    } catch (error) {
      debugPrint('Bottom bar setting unreadable: $error');
    }
  }

  /// Imposta e salva la scelta.
  Future<void> save(bool visible) async {
    _chosen = true;
    value = visible;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, visible);
    } catch (error) {
      debugPrint('Bottom bar setting not saved: $error');
    }
  }
}
