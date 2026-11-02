import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Indirizzo dello scanner proposto la prima volta.
const String kDefaultScannerAddress = '192.168.1.195';

const _prefKey = 'dart_pdf_editor_app.scanner.address';

/// L'ultimo indirizzo usato (o quello predefinito).
Future<String> loadScannerAddress() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? kDefaultScannerAddress;
  } catch (_) {
    return kDefaultScannerAddress;
  }
}

Future<void> saveScannerAddress(String address) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, address);
  } catch (_) {}
}

/// Chiede l'indirizzo dello scanner (testo normale, già compilato).
Future<String?> askScannerAddress(BuildContext context) async {
  final controller = TextEditingController(text: await loadScannerAddress());
  if (!context.mounted) return null;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Importa da scanner'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'Indirizzo dello scanner',
          helperText: 'Telefono e scanner sulla stessa rete Wi-Fi',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Scansiona'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result != null && result.isNotEmpty) await saveScannerAddress(result);
  return result;
}

/// Scansione da uno scanner di rete con il protocollo eSCL (AirScan /
/// Mopria Scan), lo stesso canale di rete della stampa ma in ricezione.
class EsclScanner {
  const EsclScanner._();

  static const _timeout = Duration(seconds: 8);

  /// Scansiona una pagina A4 dal piano di vetro a 300 dpi. Restituisce il
  /// JPEG della pagina intera.
  static Future<Uint8List> scanA4(String address) async {
    final base = await _findBase(address);
    final job = await _startJob(base);
    final page = await _nextDocument(job);
    unawaited(_deleteJob(job));
    return page;
  }

  static Future<String> _findBase(String address) async {
    var host = address.trim();
    host = host.replaceFirst(RegExp(r'^https?://'), '');
    host = host.replaceFirst(RegExp(r'/.*$'), '');
    final candidates = host.contains(':')
        ? ['http://$host']
        : ['http://$host', 'http://$host:8080'];
    for (final base in candidates) {
      try {
        final res = await http
            .get(Uri.parse('$base/eSCL/ScannerCapabilities'))
            .timeout(_timeout);
        if (res.statusCode == 200) return base;
      } catch (_) {}
    }
    throw Exception('Scanner non raggiungibile a $address');
  }

  static String _settings() => '<?xml version="1.0" encoding="UTF-8"?>'
      '<scan:ScanSettings '
      'xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm" '
      'xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03">'
      '<pwg:Version>2.0</pwg:Version>'
      '<pwg:ScanRegions><pwg:ScanRegion>'
      '<pwg:ContentRegionUnits>escl:ThreeHundredthsOfInches'
      '</pwg:ContentRegionUnits>'
      '<pwg:XOffset>0</pwg:XOffset><pwg:YOffset>0</pwg:YOffset>'
      '<pwg:Width>2481</pwg:Width><pwg:Height>3507</pwg:Height>'
      '</pwg:ScanRegion></pwg:ScanRegions>'
      '<scan:InputSource>Platen</scan:InputSource>'
      '<scan:ColorMode>RGB24</scan:ColorMode>'
      '<scan:XResolution>300</scan:XResolution>'
      '<scan:YResolution>300</scan:YResolution>'
      '<pwg:DocumentFormat>image/jpeg</pwg:DocumentFormat>'
      '</scan:ScanSettings>';

  static Future<Uri> _startJob(String base) async {
    final res = await http
        .post(
          Uri.parse('$base/eSCL/ScanJobs'),
          headers: {'Content-Type': 'text/xml'},
          body: _settings(),
        )
        .timeout(const Duration(seconds: 20));
    final location = res.headers['location'];
    if (res.statusCode != 201 || location == null) {
      throw Exception('Lo scanner ha rifiutato la scansione '
          '(codice ${res.statusCode})');
    }
    final job = Uri.parse(base).resolve(location).toString();
    return Uri.parse(job.endsWith('/') ? job.substring(0, job.length - 1) : job);
  }

  static Future<Uint8List> _nextDocument(Uri job) async {
    final url = Uri.parse('$job/NextDocument');
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (true) {
      final res = await http.get(url).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
      final busy = res.statusCode == 503 || res.statusCode == 404;
      if (!busy || DateTime.now().isAfter(deadline)) {
        throw Exception('Scansione non riuscita (codice ${res.statusCode})');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  static Future<void> _deleteJob(Uri job) async {
    try {
      await http.delete(job).timeout(_timeout);
    } catch (_) {}
  }
}
