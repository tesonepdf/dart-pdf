import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:web/web.dart' as web;

import 'app_log.dart';

extension type _LocalFont(JSObject _) implements JSObject {
  external String get family;
  external String get style;
  external JSPromise<web.Blob> blob();
}

/// All'avvio il browser non lascia leggere i font del sistema senza chiedere
/// il permesso: l'elenco parte vuoto e si riempie con
/// [loadPlatformFontsOnRequest] (voce "Font di sistema" nelle Impostazioni).
Future<List<PdfPlatformFont>> loadPlatformFonts() async => const [];

/// Chiede al browser i font installati (Local Font Access, oggi solo
/// Chrome/Edge). Dove non c'e' o il permesso e' negato resta l'elenco vuoto e
/// l'errore va nel log: l'app dira' all'utente che non e' disponibile.
Future<List<PdfPlatformFont>> loadPlatformFontsOnRequest() async {
  if (!web.window.has('queryLocalFonts')) {
    AppLog.instance.error('Font di sistema',
        'Questo browser non permette di leggere i font installati');
    throw StateError('unsupported');
  }
  try {
    final list = await web.window
        .callMethod<JSPromise<JSArray<_LocalFont>>>('queryLocalFonts'.toJS)
        .toDart;
    final byFamily = <String, _LocalFont>{};
    for (final font in list.toDart) {
      final style = font.style.toLowerCase();
      final isRegular = style == 'regular' || style == 'normal';
      if (isRegular || !byFamily.containsKey(font.family)) {
        byFamily[font.family] = font;
      }
    }
    final names = byFamily.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final family in names)
        PdfPlatformFont(
          label: family,
          family: family,
          loadBytes: () async {
            try {
              final blob = await byFamily[family]!.blob().toDart;
              final buffer = await blob.arrayBuffer().toDart;
              return buffer.toDart.asUint8List();
            } catch (e) {
              AppLog.instance.error('Font di sistema', e);
              return null;
            }
          },
        ),
    ];
  } catch (e) {
    AppLog.instance.error('Font di sistema', e);
    rethrow;
  }
}
