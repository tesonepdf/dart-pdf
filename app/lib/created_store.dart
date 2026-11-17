import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una cosa creata dall'app: scansione, foglio di foto, fumetto, documento nuovo.
@immutable
class CreatedFile {
  const CreatedFile({
    required this.kind,
    required this.title,
    required this.createdAt,
  });

  /// Che cosa e' stato creato, per esempio "Scansione" o "Fumetto".
  final String kind;
  final String title;

  /// Epoch in millisecondi.
  final int createdAt;

  Map<String, dynamic> toJson() =>
      {'k': kind, 't': title, 'c': createdAt};

  factory CreatedFile.fromJson(Map<String, dynamic> j) => CreatedFile(
        kind: (j['k'] as String?) ?? '',
        title: (j['t'] as String?) ?? '',
        createdAt: (j['c'] as num?)?.toInt() ?? 0,
      );
}

/// Le ultime creazioni, la piu' recente in cima, salvate sul dispositivo.
/// Un'unica istanza serve tutte le finestre ([instance]).
class CreatedStore extends ChangeNotifier {
  CreatedStore();

  static final CreatedStore instance = CreatedStore();

  static const _key = 'dart_pdf_editor_app.created';

  /// Quante creazioni si ricordano.
  static const maxItems = 20;

  final List<CreatedFile> _items = [];
  Future<void>? _loading;

  List<CreatedFile> get items => List.unmodifiable(_items);

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      final loaded = [
        for (final e in list)
          if (e is Map) CreatedFile.fromJson(e.cast<String, dynamic>()),
      ];
      // quello aggiunto mentre si leggeva resta in cima
      _items.addAll(loaded.where((l) => !_items.any(
          (i) => i.title == l.title && i.createdAt == l.createdAt)));
      _trim();
      notifyListeners();
    } catch (error) {
      debugPrint('Created list unreadable: $error');
    }
  }

  void _trim() {
    if (_items.length > maxItems) {
      _items.removeRange(maxItems, _items.length);
    }
  }

  /// Registra una creazione appena fatta.
  Future<void> add({required String kind, required String title}) async {
    await load();
    _items.insert(
      0,
      CreatedFile(
        kind: kind,
        title: title,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _trim();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final i in _items) i.toJson()]));
    } catch (error) {
      debugPrint('Created list not saved: $error');
    }
  }
}
