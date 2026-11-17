import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I file con la stella (scheda "Con stella" della Home), salvati sul
/// dispositivo. Ogni file e' riconosciuto dallo stesso `id` dei recenti.
///
/// Un'unica istanza serve tutte le finestre ([instance]).
class StarredStore extends ChangeNotifier {
  StarredStore();

  /// L'elenco dell'app. Va letto una volta con [load].
  static final StarredStore instance = StarredStore();

  static const _key = 'dart_pdf_editor_app.starred';

  final Set<String> _ids = {};
  Future<void>? _loading;
  bool _changed = false;

  /// Gli id che hanno la stella.
  Set<String> get ids => Set.unmodifiable(_ids);

  bool isStarred(String id) => _ids.contains(id);

  /// Legge l'elenco salvato. Si puo' chiamare piu' volte: aspettano tutte la
  /// stessa lettura.
  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key) ?? const <String>[];
      // una stella messa o tolta mentre si leggeva vince su quella salvata
      if (!_changed) {
        _ids
          ..clear()
          ..addAll(saved);
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Starred files unreadable: $error');
    }
  }

  /// Mette o toglie la stella e salva.
  Future<void> toggle(String id) async {
    _changed = true;
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _ids.toList());
    } catch (error) {
      debugPrint('Starred files not saved: $error');
    }
  }
}
