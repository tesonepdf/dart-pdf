import 'dart:convert';

/// Elenco dei file di una build Windows, nella release `app-windows-latest`.
const String kWindowsFilesManifestName = 'windows-files.json';

/// Zip completo della build Windows: prima installazione e ripiego se
/// l'aggiornamento a file non riesce.
const String kWindowsZipName = 'windows-x64.zip';

/// Avanzamento dell'aggiornamento Windows: frazione (null se non nota) e testo.
typedef WindowsUpdateProgress = void Function(double? fraction, String detail);

/// Un file della cartella dell'app Windows.
class WindowsFileEntry {
  const WindowsFileEntry({
    required this.path,
    required this.size,
    required this.sha256,
  });

  /// Percorso relativo alla cartella dell'app, con `/` come separatore.
  final String path;
  final int size;

  /// SHA-256 del file, in minuscolo.
  final String sha256;

  /// Nome del file compresso (gzip) nella release.
  String get assetName => '$sha256.gz';
}

/// L'elenco dei file di una build, come lo scrive il workflow di Windows.
class WindowsFilesManifest {
  const WindowsFilesManifest({
    required this.build,
    required this.version,
    required this.files,
  });

  final int build;
  final String version;
  final List<WindowsFileEntry> files;

  /// Legge l'elenco; null se il testo non e' un elenco valido (JSON rotto,
  /// campi mancanti, percorsi che escono dalla cartella dell'app).
  static WindowsFilesManifest? tryParse(String text) {
    try {
      final clean = text.startsWith('\uFEFF') ? text.substring(1) : text;
      final json = jsonDecode(clean);
      if (json is! Map<String, dynamic>) return null;
      final rawFiles = json['files'];
      if (rawFiles is! List) return null;
      final hashPattern = RegExp(r'^[0-9a-f]{64}$');
      final files = <WindowsFileEntry>[];
      for (final item in rawFiles) {
        if (item is! Map<String, dynamic>) return null;
        final path = item['path'];
        final size = item['size'];
        final hash = item['sha256'];
        if (path is! String || size is! int || hash is! String) return null;
        if (!_isSafeRelativePath(path) || !hashPattern.hasMatch(hash)) {
          return null;
        }
        files.add(WindowsFileEntry(path: path, size: size, sha256: hash));
      }
      final build = json['build'];
      final version = json['version'];
      return WindowsFilesManifest(
        build: build is int ? build : 0,
        version: version is String ? version : '',
        files: files,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Un percorso relativo e senza uscite dalla cartella: niente assoluti, `..`,
/// lettere di unita' o barre rovesciate.
bool _isSafeRelativePath(String path) {
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains('\\') ||
      path.contains(':')) {
    return false;
  }
  return !path.split('/').any((s) => s.isEmpty || s == '.' || s == '..');
}

/// I file da scaricare: quelli che mancano o hanno un codice diverso da quello
/// dell'elenco. [localHashes] e' il codice dei file presenti (null = manca).
List<WindowsFileEntry> windowsFilesToDownload(
  WindowsFilesManifest manifest,
  Map<String, String?> localHashes,
) =>
    [
      for (final f in manifest.files)
        if (localHashes[f.path] != f.sha256) f,
    ];

/// I file da scaricare raggruppati per codice di controllo: due file uguali
/// usano lo stesso file compresso, che si scarica una volta sola.
Map<String, List<WindowsFileEntry>> windowsDownloadsByHash(
  List<WindowsFileEntry> needed,
) {
  final out = <String, List<WindowsFileEntry>>{};
  for (final f in needed) {
    (out[f.sha256] ??= <WindowsFileEntry>[]).add(f);
  }
  return out;
}

/// Lo script (.bat) che finisce l'aggiornamento quando l'app e' chiusa:
/// aspetta che il processo [pid] termini, copia i file nuovi da [stagingDir]
/// dentro [installDir], toglie la cartella temporanea e riapre [exePath].
/// Righe separate da CRLF, come vuole il prompt dei comandi.
String buildWindowsApplyScript({
  required int pid,
  required String stagingDir,
  required String installDir,
  required String exePath,
}) {
  String v(String s) => s.replaceAll('%', '%%');
  final lines = <String>[
    '@echo off',
    'setlocal',
    'set "PID=$pid"',
    'set "STAGING=${v(stagingDir)}"',
    'set "INSTALL=${v(installDir)}"',
    'set "EXE=${v(exePath)}"',
    'set "TENTATIVI=0"',
    'set "COPIE=0"',
    ':attesa',
    'tasklist /FI "PID eq %PID%" /NH 2>nul | find "%PID%" >nul',
    'if errorlevel 1 goto copia',
    'set /a TENTATIVI+=1',
    'if %TENTATIVI% GEQ 60 goto copia',
    'ping -n 2 127.0.0.1 >nul',
    'goto attesa',
    ':copia',
    'robocopy "%STAGING%" "%INSTALL%" /E /R:3 /W:1 /NFL /NDL /NJH /NJS /NP >nul',
    'if errorlevel 8 goto riprova',
    'rd /s /q "%STAGING%"',
    'goto avvia',
    ':riprova',
    'set /a COPIE+=1',
    'if %COPIE% GEQ 5 goto avvia',
    'ping -n 3 127.0.0.1 >nul',
    'goto copia',
    ':avvia',
    'cd /d "%INSTALL%"',
    'start "" "%EXE%"',
    'del "%~f0"',
  ];
  final text = lines.join('\r\n');
  return '$text\r\n';
}
