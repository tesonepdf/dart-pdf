import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tiene vivo il lavoro dell'OCR quando l'app non è più davanti (Android).
///
/// Mentre l'OCR lavora parte un servizio in primo piano con una notifica che
/// mostra la pagina in corso: Android non ferma l'app e l'OCR continua anche
/// se apri un'altra applicazione. Finito (o annullato) il lavoro, il servizio
/// si ferma e la notifica sparisce.
///
/// Su ogni altra piattaforma, o se Android rifiuta di far partire il servizio,
/// [active] resta falso e l'OCR si comporta come prima: si mette in pausa
/// quando l'app non è visibile e riprende quando torna davanti.
class OcrBackgroundService {
  OcrBackgroundService._();

  static const MethodChannel _channel = MethodChannel(
    'dev.milanko.dartpdf/ocr_service',
  );

  static bool _active = false;

  /// Vero dal momento in cui il servizio è partito fino a [stop].
  static bool get active => _active;

  /// Il servizio esiste solo su Android.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Fa partire il servizio. Va chiamato con l'app davanti (Android non
  /// permette di far partire un servizio in primo piano dallo sfondo).
  static Future<void> start({
    required String title,
    required int page,
    required int pageCount,
  }) async {
    if (!isSupported || _active) return;
    try {
      final started = await _channel.invokeMethod<bool>('start', {
        'title': title,
        'page': page,
        'pageCount': pageCount,
      });
      _active = started ?? false;
    } on MissingPluginException {
      _active = false;
    } on PlatformException catch (error) {
      debugPrint('OCR background service not started: $error');
      _active = false;
    }
  }

  /// Aggiorna la notifica con la pagina in corso.
  static Future<void> update({
    required String title,
    required int page,
    required int pageCount,
  }) async {
    if (!_active) return;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'page': page,
        'pageCount': pageCount,
      });
    } on MissingPluginException {
      // Nessun servizio da aggiornare.
    } on PlatformException {
      // La notifica è un di più: il lavoro non deve fermarsi per lei.
    }
  }

  /// Ferma il servizio e toglie la notifica.
  static Future<void> stop() async {
    if (!_active) return;
    _active = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Già fermo.
    } on PlatformException {
      // Già fermo.
    }
  }
}
