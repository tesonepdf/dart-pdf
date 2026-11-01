import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Esito di una voce del Log.
enum AppLogLevel { ok, info, errore }

/// Una riga del Log: cosa e' successo, dove e con quale esito.
class AppLogEntry {
  AppLogEntry({
    required this.time,
    required this.level,
    required this.context,
    required this.message,
  });

  final DateTime time;
  final AppLogLevel level;

  /// L'operazione in corso, in italiano (es. "Salvataggio documento").
  final String context;

  /// Il testo tecnico originale.
  final String message;

  Map<String, dynamic> toJson() => {
        't': time.toIso8601String(),
        'l': level.name,
        'c': context,
        'm': message,
      };

  factory AppLogEntry.fromJson(Map<String, dynamic> j) => AppLogEntry(
        time: DateTime.tryParse('${j['t']}') ?? DateTime.now(),
        level: AppLogLevel.values.firstWhere(
          (e) => e.name == '${j['l']}',
          orElse: () => AppLogLevel.info,
        ),
        context: '${j['c']}',
        message: '${j['m']}',
      );
}

/// Spiegazione in italiano semplice di un errore.
class ErrorExplanation {
  const ErrorExplanation(this.cosaSuccede, this.perIDati, this.cosaFare);

  final String cosaSuccede;
  final String perIDati;
  final String cosaFare;
}

class _Rule {
  const _Rule(this.test, this.explanation);
  final RegExp test;
  final ErrorExplanation explanation;
}

final List<_Rule> _rules = [
  _Rule(
    RegExp(r'nosuchmethod|missingplugin|no implementation found|'
        r'unimplementederror|unsatisfiedlink|classnotfound'),
    const ErrorExplanation(
      'Una parte interna dell\'app o del telefono non e\' stata trovata o non '
          'risponde come previsto. Di solito e\' un difetto della versione '
          'installata, non dipende da te.',
      'L\'operazione si e\' fermata: quello che richiedeva non e\' stato '
          'eseguito. Il documento aperto non viene toccato.',
      'Controlla di avere l\'ultima versione e riprova. Se si ripete, manda il '
          'dettaglio tecnico a chi sistema l\'app.',
    ),
  ),
  _Rule(
    RegExp(r'permission|eacces|operation not permitted|securityexception|'
        r'access denied|read-only file'),
    const ErrorExplanation(
      'Il telefono non ha permesso all\'app di leggere o scrivere quel file '
          'o quella cartella.',
      'Il file non e\' stato modificato. Quello che hai fatto resta aperto '
          'nell\'app ma non e\' salvato su quel file.',
      'Usa "Salva con nome" e scegli un\'altra cartella, oppure riapri il '
          'file dalla sua posizione.',
    ),
  ),
  _Rule(
    RegExp(r'enoent|no such file|pathnotfound|filenotfound|file not found|'
        r'does not exist|cannot find'),
    const ErrorExplanation(
      'Il file non c\'e\' piu\' dov\'era: e\' stato spostato, rinominato o '
          'cancellato, oppure era una copia temporanea che il telefono ha '
          'eliminato.',
      'Non e\' stato salvato nulla su quel file.',
      'Riapri il documento dalla sua posizione attuale oppure usa "Salva con '
          'nome" per ricrearlo.',
    ),
  ),
  _Rule(
    RegExp(r'enospc|no space|disk full|storage full'),
    const ErrorExplanation(
      'La memoria del telefono e\' piena e non c\'e\' spazio per salvare.',
      'Le ultime modifiche potrebbero non essere state scritte su disco.',
      'Libera spazio sul telefono e salva di nuovo.',
    ),
  ),
  _Rule(
    RegExp(r'outofmemory|out of memory|oom'),
    const ErrorExplanation(
      'Il documento e\' troppo pesante per la memoria disponibile in questo '
          'momento.',
      'L\'operazione si e\' fermata. Le modifiche gia\' fatte restano in '
          'memoria finche l\'app resta aperta.',
      'Chiudi le altre app, salva e riprova. Con file molto grandi lavora su '
          'una pagina alla volta.',
    ),
  ),
  _Rule(
    RegExp(r'socketexception|failed host lookup|timeout|timed out|'
        r'connection (closed|refused|reset)|network'),
    const ErrorExplanation(
      'L\'app non e\' riuscita a collegarsi a internet o il server non ha '
          'risposto in tempo.',
      'Quello che era in locale sul telefono non cambia.',
      'Controlla la connessione e riprova.',
    ),
  ),
  _Rule(
    RegExp(r'formatexception|malformed|invalid pdf|not a pdf|xref|corrupt|'
        r'unexpected end'),
    const ErrorExplanation(
      'Il file non e\' un PDF valido oppure e\' danneggiato.',
      'Il file originale non e\' stato modificato.',
      'Prova ad aprirlo con un\'altra app. Se arriva da una mail, scaricalo '
          'di nuovo.',
    ),
  ),
  _Rule(
    RegExp(r'null check|is not a subtype|rangeerror|stateerror|assertion|'
        r'bad state|type \x27'),
    const ErrorExplanation(
      'Si e\' verificato un errore interno dell\'app, cioe\' un difetto nel '
          'programma. Non dipende da te.',
      'L\'operazione si e\' fermata a meta\': i passaggi fatti prima '
          'dell\'errore possono essere avvenuti, quelli dopo no.',
      'Controlla com\'e\' rimasto il documento prima di ripetere. Manda il '
          'dettaglio tecnico a chi sistema l\'app.',
    ),
  ),
  _Rule(
    RegExp(r'platformexception'),
    const ErrorExplanation(
      'Android non ha completato una richiesta dell\'app (per esempio aprire '
          'un\'altra app o leggere un file).',
      'L\'operazione richiesta non e\' stata eseguita.',
      'Riprova. Se si ripete, manda il dettaglio tecnico a chi sistema '
          'l\'app.',
    ),
  ),
];

/// Spiega in italiano un errore a partire dal testo tecnico.
ErrorExplanation explainError(String message, String context) {
  final text = message.toLowerCase();
  for (final rule in _rules) {
    if (rule.test.hasMatch(text)) return rule.explanation;
  }
  final when = context.isEmpty ? 'durante un\'operazione' : 'durante "$context"';
  return ErrorExplanation(
    'L\'app ha avuto un problema inatteso $when e l\'operazione potrebbe non '
        'essersi completata. Questo tipo di errore non ha una spiegazione '
        'preconfezionata.',
    'Non si puo\' dire con certezza cosa sia stato salvato: controlla il '
        'risultato sullo schermo e le voci vicine nel Log.',
    'Controlla se l\'operazione e\' andata a buon fine prima di ripeterla. '
        'Se l\'errore si ripresenta, manda il dettaglio tecnico a chi '
        'sistema l\'app.',
  );
}

/// Registro persistente di cio' che l'app fa e di cio' che va storto.
///
/// Si legge da Impostazioni > Log. Tiene al massimo [maxEntries] voci: oltre
/// il limite si scartano per prime le operazioni riuscite piu' vecchie, gli
/// errori restano il piu' a lungo possibile.
class AppLog extends ChangeNotifier {
  AppLog._();

  static final AppLog instance = AppLog._();

  static const _key = 'dart_pdf_editor_app.app_log_v1';
  static const maxEntries = 500;

  final List<AppLogEntry> _entries = [];
  Timer? _saveTimer;
  bool _loaded = false;
  bool _installed = false;

  /// Vero se non si riesce a scrivere il Log su disco: resta in memoria
  /// fino alla chiusura dell'app.
  bool persistFailed = false;

  /// Le voci, dalla piu' vecchia alla piu' recente.
  List<AppLogEntry> get entries => List.unmodifiable(_entries);

  /// Carica il Log salvato e aggancia gli errori non gestiti dell'app.
  Future<void> install() async {
    if (!_installed) {
      _installed = true;
      final previousFlutter = FlutterError.onError;
      FlutterError.onError = (details) {
        error('Errore dell\'app', details.exception, details.stack);
        previousFlutter?.call(details);
      };
      final previousPlatform = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (e, s) {
        error('Errore non gestito', e, s);
        return previousPlatform?.call(e, s) ?? false;
      };
    }
    await load();
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final saved = [
        for (final m in decoded.whereType<Map>())
          AppLogEntry.fromJson(m.cast<String, dynamic>()),
      ];
      _entries.insertAll(0, saved);
      _trim();
      notifyListeners();
    } catch (e) {
      persistFailed = true;
      _add(AppLogLevel.errore, 'Log',
          'Lettura del Log salvato non riuscita: $e');
    }
  }

  void ok(String context, String message) =>
      _add(AppLogLevel.ok, context, message);

  void info(String context, String message) =>
      _add(AppLogLevel.info, context, message);

  void error(String context, Object error, [StackTrace? stack]) {
    final text = stack == null ? '$error' : '$error\n$stack';
    _add(AppLogLevel.errore, context, text);
  }

  void clear() {
    _entries.clear();
    notifyListeners();
    _scheduleSave();
  }

  /// Il Log intero come testo, da copiare e mandare.
  String asText() {
    final b = StringBuffer();
    for (final e in _entries.reversed) {
      final mark = switch (e.level) {
        AppLogLevel.ok => 'OK',
        AppLogLevel.info => 'INFO',
        AppLogLevel.errore => 'ERRORE',
      };
      b.writeln('[${e.time.toIso8601String()}] $mark - ${e.context}');
      b.writeln(e.message);
      if (e.level == AppLogLevel.errore) {
        final x = explainError(e.message, e.context);
        b.writeln('Cosa succede: ${x.cosaSuccede}');
        b.writeln('Per i dati: ${x.perIDati}');
        b.writeln('Cosa fare: ${x.cosaFare}');
      }
      b.writeln();
    }
    return b.toString();
  }

  void _add(AppLogLevel level, String context, String message) {
    _entries.add(AppLogEntry(
      time: DateTime.now(),
      level: level,
      context: context,
      message: message,
    ));
    _trim();
    notifyListeners();
    _scheduleSave();
  }

  void _trim() {
    if (_entries.length <= maxEntries) return;
    var toDrop = _entries.length - maxEntries;
    _entries.removeWhere((e) {
      if (toDrop > 0 && e.level != AppLogLevel.errore) {
        toDrop--;
        return true;
      }
      return false;
    });
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode([for (final e in _entries) e.toJson()]));
      if (persistFailed) {
        persistFailed = false;
        notifyListeners();
      }
    } catch (_) {
      if (!persistFailed) {
        persistFailed = true;
        notifyListeners();
      }
    }
  }
}
