import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Apre un file (per esempio un `.docx`) con l'app scelta da Android: scrive il
/// file nella cartella temporanea e chiede ad Android di aprirlo. Solo Android.
class OpenFileExternal {
  static const _channel = MethodChannel('dev.milanko.dartpdf/openfile');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Restituisce `null` se il file e' stato aperto, altrimenti un messaggio in
  /// italiano da mostrare.
  static Future<String?> view(
    Uint8List bytes, {
    required String name,
    required String mimeType,
    required String appName,
  }) async {
    if (!supported) {
      return '\"Apri in $appName\" c\'e\' solo su Android: usa la voce Esporta.';
    }
    try {
      await _channel.invokeMethod<String>('view', {
        'bytes': bytes,
        'name': name,
        'mime': mimeType,
      });
      return null;
    } on PlatformException catch (e) {
      if (e.code == 'noapp') {
        return 'Sul telefono non c\'e\' nessuna app che apre questo file. '
            'Installa $appName oppure usa la voce Esporta.';
      }
      return 'Non riesco ad aprire il file: ${e.message ?? e.code}';
    }
  }
}
