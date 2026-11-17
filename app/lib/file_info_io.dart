import 'dart:io';

import 'file_info.dart';

/// Legge peso e ultima modifica dal file; null se non c'e' o non si legge.
Future<FileInfo?> readFileInfo(String path) async {
  try {
    final stat = await File(path).stat();
    if (stat.type != FileSystemEntityType.file) return null;
    return FileInfo(size: stat.size, modified: stat.modified);
  } catch (_) {
    return null;
  }
}
