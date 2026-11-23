import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';
import 'app_log.dart';

const _tokenKey = 'log_upload_token';
const _folder = '/repos/note1977/note/contents/dart-pdf/log';

/// Il token GitHub per inviare il Log, se e' gia' stato inserito.
Future<String?> savedLogToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_tokenKey);
  return token == null || token.trim().isEmpty ? null : token.trim();
}

Future<void> saveLogToken(String? token) async {
  final prefs = await SharedPreferences.getInstance();
  if (token == null || token.trim().isEmpty) {
    await prefs.remove(_tokenKey);
  } else {
    await prefs.setString(_tokenKey, token.trim());
  }
}

/// Carica il Log intero nel repo privato note1977/note, cartella dart-pdf/log,
/// in un file che ha l'identificativo della build nel nome. Torna il nome del
/// file; se GitHub rifiuta, lancia un errore con il motivo.
Future<String> uploadLog(String token) async {
  String two(int n) => n.toString().padLeft(2, '0');
  final now = DateTime.now();
  final stamp = '${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  final name = '${AppInfo.displayVersion}_$stamp.txt';
  final text = 'DartPDF ${AppInfo.displayVersion}\n'
      'Inviato il ${now.toIso8601String()}\n\n${AppLog.instance.asText()}';
  final response = await http.put(
    Uri.https('api.github.com', '$_folder/$name'),
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github+json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'message': 'Log $name',
      'content': base64Encode(utf8.encode(text)),
      'branch': 'main',
    }),
  );
  if (response.statusCode == 201 || response.statusCode == 200) return name;
  var reason = 'errore ${response.statusCode}';
  try {
    final body = jsonDecode(response.body);
    if (body is Map && body['message'] is String) {
      reason = '${response.statusCode}: ${body['message']}';
    }
  } catch (_) {}
  if (response.statusCode == 401 || response.statusCode == 403) {
    await saveLogToken(null);
  }
  throw Exception(reason);
}
