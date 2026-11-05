import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Legge ad alta voce un testo con la voce di sistema (Android, iOS, macOS,
/// Windows). Il testo lungo viene spezzato in blocchi, perché i motori vocali
/// accettano al massimo qualche migliaio di caratteri per volta.
class ReadAloud {
  ReadAloud._();

  static final ReadAloud instance = ReadAloud._();

  /// Quanti caratteri al massimo per blocco (Android ne accetta circa 4000).
  static const int _maxChunk = 3000;

  FlutterTts? _tts;
  int _run = 0;

  /// Vero mentre la voce sta leggendo.
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  /// Spezza [text] in blocchi di al più [_maxChunk] caratteri, preferendo la
  /// fine di una frase o di una riga.
  @visibleForTesting
  static List<String> chunks(String text) {
    final clean = text.replaceAll('\r', '').trim();
    final out = <String>[];
    var rest = clean;
    while (rest.isNotEmpty) {
      if (rest.length <= _maxChunk) {
        out.add(rest);
        break;
      }
      var cut = rest.lastIndexOf(RegExp(r'[.!?\n]'), _maxChunk);
      if (cut < _maxChunk ~/ 2) cut = rest.lastIndexOf(' ', _maxChunk);
      if (cut < _maxChunk ~/ 2) cut = _maxChunk - 1;
      out.add(rest.substring(0, cut + 1).trim());
      rest = rest.substring(cut + 1).trim();
    }
    return [
      for (final c in out)
        if (c.isNotEmpty) c,
    ];
  }

  /// Legge [text] nella lingua [languageTag] (per esempio `it-IT`). Se sta già
  /// leggendo, riparte dal nuovo testo.
  Future<void> speak(String text, {String? languageTag}) async {
    final parts = chunks(text);
    if (parts.isEmpty) return;
    await stop();
    final run = ++_run;
    speaking.value = true;
    try {
      final tts = _tts ??= FlutterTts();
      await tts.awaitSpeakCompletion(true);
      if (languageTag != null) {
        try {
          await tts.setLanguage(languageTag);
        } catch (_) {
          // lingua non disponibile: resta quella di sistema
        }
      }
      for (final part in parts) {
        if (run != _run) return;
        await tts.speak(part);
      }
    } catch (e) {
      debugPrint('read aloud failed: $e');
    } finally {
      if (run == _run) speaking.value = false;
    }
  }

  /// Ferma la lettura.
  Future<void> stop() async {
    _run++;
    speaking.value = false;
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

/// Lingua della voce a partire dalla lingua dell'app.
String readAloudLanguageTag(String languageCode) => switch (languageCode) {
      'it' => 'it-IT',
      'en' => 'en-US',
      'de' => 'de-DE',
      'fr' => 'fr-FR',
      'es' => 'es-ES',
      'pt' => 'pt-PT',
      _ => languageCode,
    };

/// Testi dei comandi di lettura, nella lingua dell'app.
({String read, String stop, String page}) readAloudLabels(String languageCode) {
  return languageCode == 'it'
      ? (
          read: 'Leggi ad alta voce',
          stop: 'Ferma la lettura',
          page: 'Leggi la pagina ad alta voce'
        )
      : (
          read: 'Read aloud',
          stop: 'Stop reading',
          page: 'Read the page aloud'
        );
}
