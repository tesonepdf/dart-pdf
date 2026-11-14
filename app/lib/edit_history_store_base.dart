import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfEditHistorySnapshot;

/// L'archivio della cronologia annulla/ripeti.
///
/// La cronologia e' legata al CONTENUTO del documento, non al suo nome o
/// percorso: la chiave e' la lunghezza piu' l'impronta SHA-256 dei byte della
/// revisione corrente. Alla riapertura, da qualunque via (recenti, sessione
/// ripristinata, recupero delle modifiche), se i byte sono gli stessi la
/// cronologia torna; un file diverso non la ritrova mai.
abstract class EditHistoryStore {
  /// La cronologia salvata per questi [bytes], o null.
  Future<PdfEditHistorySnapshot?> load(Uint8List bytes);

  /// Salva [snapshot] per questi [bytes] (la revisione corrente). Restituisce
  /// la chiave usata, o null se non e' stato possibile.
  Future<String?> save(Uint8List bytes, PdfEditHistorySnapshot snapshot);

  /// Toglie la cronologia con questa chiave.
  Future<void> remove(String key);
}
