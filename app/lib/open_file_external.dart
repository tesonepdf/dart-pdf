import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_log.dart';
import 'open_file_temp_stub.dart'
    if (dart.library.io) 'open_file_temp_io.dart' as temp;

/// "Apri in Word / Excel": su tutti i sistemi la voce del menu c'e'.
///
/// * Android: apre il file con l'app scelta da Android.
/// * Windows, macOS, Linux: scrive il file nella cartella temporanea e lo apre
///   con il programma associato al tipo di file.
/// * iPhone e iPad: foglio di condivisione, dove si sceglie Word o Excel.
/// * Web: il browser scarica il file e lo si apre da li'.
///
/// Se sul sistema non c'e' Word (o Excel) non e' un problema dell'editor: il
/// messaggio in italiano compare a video e l'errore va nel log.
class OpenFileExternal {
  static const _channel = MethodChannel('dev.milanko.dartpdf/openfile');

  /// Sempre vera: la voce del menu non sparisce mai (paletto 1).
  static bool get supported => true;

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static String get _systemName =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Restituisce `null` se il file e' stato aperto, altrimenti un messaggio in
  /// italiano da mostrare.
  static Future<String?> view(
    Uint8List bytes, {
    required String name,
    required String mimeType,
    required String appName,
  }) async {
    try {
      if (_android) return await _viewAndroid(bytes, name, mimeType, appName);
      final file = XFile.fromData(bytes, mimeType: mimeType, name: name);
      if (kIsWeb) {
        await file.saveTo(name);
        AppLog.instance.ok('Apri in $appName', 'File "$name" scaricato');
        return 'Il file e\' stato scaricato: aprilo con $appName.';
      }
      if (_ios) {
        await SharePlus.instance.share(ShareParams(
          files: [file],
          fileNameOverrides: [name],
          title: name,
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ));
        AppLog.instance.ok('Apri in $appName', 'Foglio di condivisione per "$name"');
        return null;
      }
      final path = await temp.writeTempFile(bytes, name);
      final opened = await launchUrl(Uri.file(path));
      if (!opened) {
        AppLog.instance.error('Apri in $appName',
            'Nessun programma ha aperto $path ($_systemName)');
        return 'Non trovo un programma che apre questo file. '
            'Installa $appName oppure usa la voce Esporta.';
      }
      AppLog.instance.ok('Apri in $appName', 'Aperto $path');
      return null;
    } catch (e) {
      AppLog.instance.error('Apri in $appName', '$_systemName: $e');
      return 'Non riesco ad aprire il file con $appName: $e';
    }
  }

  static Future<String?> _viewAndroid(
      Uint8List bytes, String name, String mimeType, String appName) async {
    try {
      await _channel.invokeMethod<String>('view', {
        'bytes': bytes,
        'name': name,
        'mime': mimeType,
      });
      return null;
    } on PlatformException catch (e) {
      AppLog.instance.error('Apri in $appName', e);
      if (e.code == 'noapp') {
        return 'Sul telefono non c\'e\' nessuna app che apre questo file. '
            'Installa $appName oppure usa la voce Esporta.';
      }
      return 'Non riesco ad aprire il file: ${e.message ?? e.code}';
    }
  }
}
