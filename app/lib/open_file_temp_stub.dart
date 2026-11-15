import 'dart:typed_data';

/// Senza disco (web) non si scrive nulla: il file si scarica dal browser.
Future<String> writeTempFile(Uint8List bytes, String name) async =>
    throw UnsupportedError('Nessun disco su questo sistema');
