import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart' show showPdfDialog;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';
import 'file_io.dart';

/// La cartella dove DartPDF salva i PDF (solo Android). Si sceglie col
/// selettore di cartelle di Android (dove si puo' anche crearne una nuova) e
/// resta quella finche' non la si cambia in Impostazioni.
class SaveFolder {
  static const _channel = MethodChannel('dev.milanko.dartpdf/savefolder');
  static const _uriKey = 'dart_pdf_editor_app.save_folder.uri';
  static const _nameKey = 'dart_pdf_editor_app.save_folder.name';

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Chiamata quando cambia la cartella, per aggiornare le Impostazioni.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static Future<({String uri, String name})?> current() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_uriKey);
    if (uri == null || uri.isEmpty) return null;
    return (uri: uri, name: prefs.getString(_nameKey) ?? 'Cartella scelta');
  }

  /// Apre il selettore di cartelle. Null se si annulla.
  static Future<({String uri, String name})?> pick() async {
    try {
      final r = await _channel.invokeMapMethod<String, String>('pick');
      if (r == null) return null;
      final uri = r['uri'];
      final name = r['name'] ?? 'Cartella scelta';
      if (uri == null) return null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_uriKey, uri);
      await prefs.setString(_nameKey, name);
      AppLog.instance.ok('Cartella di salvataggio', 'Impostata: $name');
      changes.value++;
      return (uri: uri, name: name);
    } catch (e, s) {
      AppLog.instance.error('Cartella di salvataggio', e, s);
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uriKey);
    await prefs.remove(_nameKey);
    AppLog.instance.ok('Cartella di salvataggio', 'Rimossa');
    changes.value++;
  }

  static Future<bool> _askToChoose(BuildContext context) async {
    final choose = await showPdfDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dove salvare i PDF?'),
        content: const Text(
          'Scegli una cartella del telefono (puoi anche crearne una nuova '
          'dal selettore). I PDF salvati andranno sempre li, finche non la '
          'cambi in Impostazioni.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Scegli cartella'),
          ),
        ],
      ),
    );
    return choose ?? false;
  }

  /// Il nome con cui [suggestedName] finisce nella cartella: caratteri non
  /// ammessi sistemati ([safeFileName]) ed estensione `.pdf`.
  static String fileNameFor(String suggestedName) {
    var name = safeFileName(suggestedName);
    if (name.isEmpty) name = 'documento.pdf';
    if (!name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';
    return name;
  }

  /// Se nella cartella scelta c'e' gia' un file con questo nome (quello che
  /// [fileNameFor] ha dato). False se non c'e' una cartella o non si riesce a
  /// leggerla.
  static Future<bool> exists(String fileName) async {
    final folder = await current();
    if (folder == null) return false;
    try {
      return await _channel.invokeMethod<bool>(
              'exists', {'treeUri': folder.uri, 'name': fileName}) ??
          false;
    } catch (e, s) {
      AppLog.instance.error('Cartella di salvataggio', e, s);
      return false;
    }
  }

  /// Salva [bytes] nella cartella scelta, chiedendola la prima volta.
  /// Un file con lo stesso nome viene sovrascritto.
  static Future<SaveResult> save(
      BuildContext context, Uint8List bytes, String suggestedName) async {
    var folder = await current();
    if (folder == null) {
      if (!context.mounted || !await _askToChoose(context)) {
        return SaveResult.cancelled;
      }
      folder = await pick();
      if (folder == null) return SaveResult.cancelled;
    }
    final name = fileNameFor(suggestedName);
    try {
      await _channel.invokeMethod<String>('save', {
        'treeUri': folder.uri,
        'name': name,
        'bytes': bytes,
      });
      AppLog.instance.ok('Salvataggio documento',
          'Scritto "$name" nella cartella "${folder.name}"');
      return SaveResult.savedInFolder(folder.name, name);
    } catch (e, s) {
      AppLog.instance.error('Salvataggio documento', e, s);
      return SaveResult.failed(e);
    }
  }
}
