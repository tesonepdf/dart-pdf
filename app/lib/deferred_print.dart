import 'dart:convert';
import 'dart:typed_data';

// Stampa differita: i fogli gia' composti (pagine scelte, orientamento,
// fronte/retro, pagine per foglio) restano in una coda finche' l'utente non
// li stampa; dopo la stampa il gruppo si cancella.
//
// Ogni voce della coda e' un gruppo: un PDF con i fogli pronti piu' una riga
// di riepilogo ("Fronte/retro · Verticale · A4"). Un archivio per piattaforma
// (file su disco; in memoria dove non c'e' disco) tiene i byte.

/// Un gruppo di fogli in attesa di stampa.
class DeferredPrintItem {
  const DeferredPrintItem({
    required this.id,
    required this.name,
    required this.summary,
    required this.pages,
    required this.sheets,
    required this.createdAt,
    this.twoSided = false,
  });

  final String id;

  /// Nome mostrato in elenco (modificabile).
  final String name;

  /// Riepilogo delle scelte: fronte/retro, orientamento, carta.
  final String summary;

  /// Pagine del documento di partenza.
  final int pages;

  /// Fogli (pagine del PDF pronto).
  final int sheets;
  final DateTime createdAt;
  final bool twoSided;

  DeferredPrintItem copyWith({String? name}) => DeferredPrintItem(
        id: id,
        name: name ?? this.name,
        summary: summary,
        pages: pages,
        sheets: sheets,
        createdAt: createdAt,
        twoSided: twoSided,
      );

  String toJson() => jsonEncode({
        'id': id,
        'name': name,
        'summary': summary,
        'pages': pages,
        'sheets': sheets,
        'createdAt': createdAt.toIso8601String(),
        'twoSided': twoSided,
      });

  static DeferredPrintItem? fromJson(String text) {
    try {
      final map = jsonDecode(text);
      if (map is! Map) return null;
      final id = map['id'];
      final name = map['name'];
      if (id is! String || name is! String) return null;
      return DeferredPrintItem(
        id: id,
        name: name,
        summary: (map['summary'] as String?) ?? '',
        pages: (map['pages'] as num?)?.toInt() ?? 0,
        sheets: (map['sheets'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
            DateTime.now(),
        twoSided: map['twoSided'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Dove restano i gruppi in attesa.
abstract class DeferredPrintStore {
  /// Dal piu' vecchio al piu' recente.
  Future<List<DeferredPrintItem>> list();

  Future<void> add(DeferredPrintItem item, Uint8List bytes);

  Future<Uint8List?> read(String id);

  Future<void> rename(String id, String name);

  Future<void> remove(String id);
}

/// Archivio in memoria: per il web e per i test.
class MemoryDeferredPrintStore implements DeferredPrintStore {
  final Map<String, DeferredPrintItem> _items = {};
  final Map<String, Uint8List> _bytes = {};

  @override
  Future<List<DeferredPrintItem>> list() async {
    final items = _items.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<void> add(DeferredPrintItem item, Uint8List bytes) async {
    _items[item.id] = item;
    _bytes[item.id] = bytes;
  }

  @override
  Future<Uint8List?> read(String id) async => _bytes[id];

  @override
  Future<void> rename(String id, String name) async {
    final item = _items[id];
    if (item != null) _items[id] = item.copyWith(name: name);
  }

  @override
  Future<void> remove(String id) async {
    _items.remove(id);
    _bytes.remove(id);
  }
}

/// Riepilogo delle scelte di un gruppo, per l'elenco.
String deferredSummary({
  required bool twoSided,
  required String orientation,
  required String paper,
}) {
  final parts = <String>[
    twoSided ? 'Fronte/retro' : 'Solo fronte',
    if (orientation.isNotEmpty) orientation,
    if (paper.isNotEmpty) paper,
  ];
  return parts.join(' · ');
}
