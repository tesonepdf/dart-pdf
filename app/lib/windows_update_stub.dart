import 'package:http/http.dart' as http;

import 'windows_files.dart';

/// Senza dart:io (web) non c'e' nessun aggiornamento a file.
Future<void> applyWindowsFilesUpdate({
  required Map<String, String> assets,
  required Map<String, int> assetSizes,
  required bool Function() isCancelled,
  required WindowsUpdateProgress onProgress,
  http.Client Function()? clientFactory,
}) async {
  throw UnsupportedError("L'aggiornamento a file e' disponibile solo su Windows");
}
