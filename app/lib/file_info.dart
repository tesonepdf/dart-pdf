import 'file_info_stub.dart' if (dart.library.io) 'file_info_io.dart' as impl;

/// Dimensione e ultima modifica di un file sul dispositivo.
class FileInfo {
  const FileInfo({required this.size, required this.modified});

  /// Peso in byte.
  final int size;

  /// Data e ora dell'ultima modifica.
  final DateTime modified;
}

/// Legge le informazioni di un file; null se non si possono leggere.
typedef FileInfoReader = Future<FileInfo?> Function(String path);

/// Il lettore dell'app: legge il file vero (non c'e' sul web).
Future<FileInfo?> readFileInfo(String path) => impl.readFileInfo(path);

/// "307,4 KB", "2,8 MB": il peso con la virgola, in multipli di 1024.
String formatFileSize(int bytes) {
  String one(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${one(kb)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${one(mb)} MB';
  return '${one(mb / 1024)} GB';
}

const _months = [
  'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
  'lug', 'ago', 'set', 'ott', 'nov', 'dic', //
];

/// "17 nov, 08:34"; con l'anno ("17 nov 2025, 08:34") se non e' quello di [now].
String formatFileDate(DateTime d, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final year = d.year == now.year ? '' : ' ${d.year}';
  return '${d.day} ${_months[d.month - 1]}$year, ${two(d.hour)}:${two(d.minute)}';
}
