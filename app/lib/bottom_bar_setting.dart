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

/// La scelta "Il pulsante del menu mostra anche la barra": con la barra in
/// basso nascosta, il pulsante in alto a sinistra apre il menu e, se questa
/// scelta e' accesa, fa comparire anche la barra. Spenta di base: esce solo il
/// menu a fisarmonica. Salvata sul dispositivo, vale per tutte le finestre.
class BottomBarMenuButtonSetting extends ValueNotifier<bool> {
  BottomBarMenuButtonSetting() : super(false);

  static final BottomBarMenuButtonSetting instance =
      BottomBarMenuButtonSetting();

  static const _key = 'dart_pdf_editor_app.bottom_bar_menu_button';

  Future<void>? _loading;
  bool _chosen = false;

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_chosen) value = prefs.getBool(_key) ?? false;
    } catch (error) {
      debugPrint('Menu button setting unreadable: $error');
    }
  }

  Future<void> save(bool shows) async {
    _chosen = true;
    value = shows;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, shows);
    } catch (error) {
      debugPrint('Menu button setting not saved: $error');
    }
  }
}

/// La barra in basso fatta comparire dal pulsante del menu (solo se la barra
/// e' nascosta da Impostazioni e [BottomBarMenuButtonSetting] e' accesa).
/// Non si salva: a ogni avvio la barra nascosta resta nascosta.
class BottomBarPeek {
  BottomBarPeek._();

  static final ValueNotifier<bool> visible = ValueNotifier<bool>(false);

  /// Il pulsante del menu e' stato premuto: se serve, mostra o nasconde la barra.
  static void onMenuButton() {
    if (BottomBarMenuButtonSetting.instance.value &&
        !BottomBarSetting.instance.value) {
      visible.value = !visible.value;
    }
  }
}
