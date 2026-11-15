import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_log.dart';

/// Porta DartPDF in cima all'elenco "Apri con" di Android (solo Android):
/// apre l'elenco di sistema su un PDF minimo; scegliendo DartPDF l'app risale
/// tra le app usate di recente.
class OpenWithRank {
  static const _channel = MethodChannel('dev.milanko.dartpdf/openwith');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Restituisce `null` se l'elenco e' stato aperto, altrimenti un messaggio
  /// in italiano da mostrare (e scrive l'errore nel log).
  static Future<String?> show() async {
    if (!supported) {
      const message =
          '\"Apri con\" si gestisce solo su Android: su questo sistema '
          'non c\'e\' nulla da fare.';
      AppLog.instance.error('Apri con', 'Non disponibile su questo sistema '
          '(${kIsWeb ? 'web' : defaultTargetPlatform.name})');
      return message;
    }
    try {
      await _channel.invokeMethod<String>('show');
      return null;
    } on PlatformException catch (e) {
      AppLog.instance.error('Apri con', e);
      return 'Non riesco ad aprire l\'elenco \"Apri con\": ${e.message ?? e.code}';
    }
  }
}
