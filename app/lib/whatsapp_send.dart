import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart' show showPdfDialog;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatsappContact {
  const WhatsappContact(this.name, this.number);
  final String name;
  final String number;

  Map<String, String> toJson() => {'name': name, 'number': number};
}

/// Invio di un PDF su WhatsApp (solo Android): a uno dei contatti salvati
/// (chat aperta direttamente) oppure a un contatto scelto in WhatsApp.
class WhatsappSend {
  static const _channel = MethodChannel('dev.milanko.dartpdf/whatsapp');
  static const _key = 'dart_pdf_editor_app.whatsapp_contacts';
  static const _oldKey = 'dart_pdf_editor_app.whatsapp_number';

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<List<WhatsappContact>> contacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final list = <WhatsappContact>[];
    if (raw != null) {
      try {
        for (final m in (jsonDecode(raw) as List).whereType<Map>()) {
          list.add(WhatsappContact('${m['name']}', '${m['number']}'));
        }
      } catch (_) {}
    }
    final old = prefs.getString(_oldKey);
    if (old != null && old.isNotEmpty && list.isEmpty) {
      list.add(WhatsappContact('Contatto', old));
    }
    return list;
  }

  static Future<void> _save(List<WhatsappContact> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_oldKey);
    await prefs.setString(_key, jsonEncode([for (final c in list) c.toJson()]));
  }

  /// Solo cifre, con prefisso internazionale (un cellulare italiano da 10
  /// cifre che inizia per 3 prende 39).
  static String? normalize(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 10 && digits.startsWith('3')) digits = '39$digits';
    return digits.length < 6 ? null : digits;
  }

  static Future<WhatsappContact?> _askNewContact(BuildContext context) async {
    final name = TextEditingController();
    final number = TextEditingController();
    String? error;
    final result = await showPdfDialog<WhatsappContact>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuovo contatto'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nome'),
            ),
            TextField(
              controller: number,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Numero, es. 339 1234567',
                errorText: error,
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final n = normalize(number.text);
                if (n == null) {
                  setState(() => error = 'Numero non valido');
                  return;
                }
                final label = name.text.trim();
                Navigator.of(dialogContext)
                    .pop(WhatsappContact(label.isEmpty ? n : label, n));
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    number.dispose();
    return result;
  }

  /// Elenco dei contatti salvati: si tocca per scegliere, la X toglie, "+"
  /// aggiunge. Ritorna il contatto scelto, null se si chiude.
  static Future<WhatsappContact?> pickContact(BuildContext context) async {
    var list = await contacts();
    if (!context.mounted) return null;
    if (list.isEmpty) {
      final added = await _askNewContact(context);
      if (added == null) return null;
      await _save([added]);
      return added;
    }
    return showPdfDialog<WhatsappContact>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invia a'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(shrinkWrap: true, children: [
              for (final c in list)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(c.name),
                  subtitle: Text('+${c.number}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      list = [
                        for (final x in list)
                          if (x.number != c.number) x
                      ];
                      await _save(list);
                      if (list.isEmpty && dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(c),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Aggiungi contatto'),
                onTap: () async {
                  final added = await _askNewContact(dialogContext);
                  if (added == null) return;
                  list = [
                    for (final x in list)
                      if (x.number != added.number) x,
                    added,
                  ];
                  await _save(list);
                  setState(() {});
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      ),
    );
  }

  /// Manda [bytes] su WhatsApp. Con [number] apre la chat di quel numero,
  /// senza sceglie l'utente il contatto dentro WhatsApp.
  /// Ritorna 'ok' o 'no_whatsapp'.
  static Future<String?> send({
    required Uint8List bytes,
    required String name,
    String? number,
  }) =>
      _channel.invokeMethod<String>('send', {
        'bytes': bytes,
        'name': name,
        'number': number,
      });
}
