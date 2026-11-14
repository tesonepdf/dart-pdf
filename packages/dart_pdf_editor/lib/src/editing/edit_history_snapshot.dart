import 'dart:typed_data';

/// Una copia portabile della cronologia annulla/ripeti di una sessione di
/// modifica, per salvarla fuori dalla memoria e rimetterla alla riapertura.
///
/// Ogni revisione e' un prefisso dello stesso buffer: le lunghezze in
/// [revisions] dicono dove finisce ciascuna, [cursor] dice quale e' quella
/// corrente. Le revisioni fino a quella corrente stanno gia' nel file; in
/// [tail] ci sono solo i byte oltre la corrente (la parte "ripeti").
class PdfEditHistorySnapshot {
  const PdfEditHistorySnapshot({
    required this.revisions,
    required this.cursor,
    required this.tail,
  });

  /// Lunghezza in byte di ogni revisione, dalla piu' vecchia. La prima e'
  /// il documento com'era all'apertura.
  final List<int> revisions;

  /// Indice in [revisions] della revisione corrente.
  final int cursor;

  /// I byte dopo la revisione corrente (vuoto se non c'e' niente da ripetere).
  final Uint8List tail;

  /// Quanti passi si possono annullare.
  int get undoSteps => cursor;

  /// Quanti passi si possono ripetere.
  int get redoSteps => revisions.length - 1 - cursor;
}
