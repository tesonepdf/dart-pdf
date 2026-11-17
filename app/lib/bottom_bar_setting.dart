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

/// La scelta "Home come schermata iniziale": senza documento aperto, al posto
/// della schermata di benvenuto si vede la Home (scorciatoie e file recenti).
/// Spenta di base. Salvata sul dispositivo, vale per tutte le finestre.
class StartHomeSetting extends ValueNotifier<bool> {
  StartHomeSetting() : super(false);

  static final StartHomeSetting instance = StartHomeSetting();

  static const _key = 'dart_pdf_editor_app.start_home';

  Future<void>? _loading;
  bool _chosen = false;

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_chosen) value = prefs.getBool(_key) ?? false;
    } catch (error) {
      debugPrint('Start home setting unreadable: $error');
    }
  }

  Future<void> save(bool home) async {
    _chosen = true;
    value = home;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, home);
    } catch (error) {
      debugPrint('Start home setting not saved: $error');
    }
  }
}

/// La scelta "Barra del documento stile tesone": con un documento aperto, in
/// alto freccia, riflusso, altoparlante, ricerca, condividi e tre puntini; in
/// basso Modifica PDF, Commento, Evidenzia, Disegna, Compila e firma e Altri
/// strumenti. Spenta di base. Salvata sul dispositivo, vale per tutte le finestre.
class TesoneBarSetting extends ValueNotifier<bool> {
  TesoneBarSetting() : super(false);

  static final TesoneBarSetting instance = TesoneBarSetting();

  static const _key = 'dart_pdf_editor_app.tesone_bar';

  Future<void>? _loading;
  bool _chosen = false;

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_chosen) value = prefs.getBool(_key) ?? false;
    } catch (error) {
      debugPrint('Tesone bar setting unreadable: $error');
    }
  }

  Future<void> save(bool on) async {
    _chosen = true;
    value = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, on);
    } catch (error) {
      debugPrint('Tesone bar setting not saved: $error');
    }
  }
}

/// La scelta "Vista griglia" della Home: i file in una griglia di miniature
/// invece che in un elenco. Spenta di base, salvata sul dispositivo.
class HomeGridSetting extends ValueNotifier<bool> {
  HomeGridSetting() : super(false);

  static final HomeGridSetting instance = HomeGridSetting();

  static const _key = 'dart_pdf_editor_app.home_grid';

  Future<void>? _loading;
  bool _chosen = false;

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_chosen) value = prefs.getBool(_key) ?? false;
    } catch (error) {
      debugPrint('Home grid setting unreadable: $error');
    }
  }

  Future<void> save(bool grid) async {
    _chosen = true;
    value = grid;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, grid);
    } catch (error) {
      debugPrint('Home grid setting not saved: $error');
    }
  }
}
