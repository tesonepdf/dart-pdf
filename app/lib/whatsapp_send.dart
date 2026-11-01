import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Invio diretto di un PDF alla chat WhatsApp di un contatto fisso (solo
/// Android). Il numero si inserisce una volta e resta salvato.
class WhatsappSend {
  static const _channel = MethodChannel('dev.milanko.dartpdf/whatsapp');
  static const _key = 'dart_pdf_editor_app.whatsapp_number';

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String?> savedNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> saveNumber(String? number) async {
    final prefs = await SharedPreferences.getInstance();
    if (number == null || number.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, number);
    }
  }

  /// Solo cifre, con prefisso internazionale (un cellulare italiano da 10
  /// cifre che inizia per 3 prende 39).
  static String? normalize(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 10 && digits.startsWith('3')) digits = '39$digits';
    return digits.length < 8 ? null : digits;
  }

  /// Chiede il numero del contatto. Null se annullato.
  static Future<String?> askNumber(BuildContext context,
      {String? current}) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contatto WhatsApp'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Numero, es. 339 1234567',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(normalize(controller.text)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) await saveNumber(result);
    return result;
  }

  /// Manda [bytes] alla chat del [number]. Ritorna 'ok' o 'no_whatsapp'.
  static Future<String?> send({
    required Uint8List bytes,
    required String name,
    required String number,
  }) =>
      _channel.invokeMethod<String>('send', {
        'bytes': bytes,
        'name': name,
        'number': number,
      });
}
