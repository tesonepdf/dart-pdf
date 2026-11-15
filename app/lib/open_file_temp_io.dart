import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Scrive [bytes] nella cartella temporanea e ritorna il percorso del file.
Future<String> writeTempFile(Uint8List bytes, String name) async {
  final dir = await getTemporaryDirectory();
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${dir.path}${Platform.pathSeparator}$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
