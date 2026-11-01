import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Porta DartPDF in cima all'elenco "Apri con" di Android (solo Android):
/// apre l'elenco di sistema su un PDF minimo; scegliendo DartPDF l'app risale
/// tra le app usate di recente.
class OpenWithRank {
  static const _channel = MethodChannel('dev.milanko.dartpdf/openwith');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> show() async {
    try {
      await _channel.invokeMethod<String>('show');
    } on PlatformException catch (_) {}
  }
}
