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

/// Tipo di una voce del Log, per filtrare l'elenco.
enum AppLogType {
  documenti('Documenti'),
  recenti('Recenti'),
  ocr('OCR'),
  aggiornamenti('Aggiornamenti'),
  invioStampa('Invio e stampa'),
  app('App');

  const AppLogType(this.label);

  /// Il nome mostrato nel filtro.
  final String label;
}

/// A quale tipo appartiene una voce, a partire dal suo argomento (`context`).
AppLogType appLogTypeOf(String context) {
  final c = context.toLowerCase();
  if (c.contains('aggiorn')) return AppLogType.aggiornamenti;
  if (c.contains('ocr')) return AppLogType.ocr;
  if (c.contains('recent')) return AppLogType.recenti;
  if (c.contains('whatsapp') || c.contains('stampa') || c.contains('invio')) {
    return AppLogType.invioStampa;
  }
  if (c == 'salvataggio documento' || c.contains('cartella di salvataggio')) {
    return AppLogType.documenti;
  }
  return AppLogType.app;
}

/// Scelte del filtro per data.
enum AppLogDateRange { tutte, oggi, ieri, ultimi7, giorno }

/// Vero se [time] cade nell'intervallo scelto. Con [AppLogDateRange.giorno]
/// conta il giorno indicato in [day].
bool appLogInDateRange(
  DateTime time,
  AppLogDateRange range,
  DateTime now, {
  DateTime? day,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(time.year, time.month, time.day);
  switch (range) {
    case AppLogDateRange.tutte:
      return true;
    case AppLogDateRange.oggi:
      return d == today;
    case AppLogDateRange.ieri:
      return d == DateTime(today.year, today.month, today.day - 1);
    case AppLogDateRange.ultimi7:
      final first = DateTime(today.year, today.month, today.day - 6);
      return !d.isBefore(first) && !d.isAfter(today);
    case AppLogDateRange.giorno:
      return day != null && d == DateTime(day.year, day.month, day.day);
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Quando e' successo, in forma breve: "Oggi 11:25:13", "Ieri 09:02:40",
/// oppure "10/11 18:30:05".
String appLogWhen(DateTime t, DateTime now) {
  final hms = '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(t.year, t.month, t.day);
  if (d == today) return 'Oggi $hms';
  if (d == DateTime(today.year, today.month, today.day - 1)) {
    return 'Ieri $hms';
  }
  return '${_two(t.day)}/${_two(t.month)} $hms';
}

class _Say {
  const _Say(this.context, this.pattern, this.build);

  final String context;
  final RegExp pattern;
  final String Function(RegExpMatch m) build;
}

final List<_Say> _says = [
  // Recenti
  _Say('Recenti', RegExp(r'^Caricati (\d+) file recenti'),
      (m) => 'All\'apertura dell\'app ho caricato l\'elenco dei file recenti '
          '(${m[1]}).'),
  _Say('Recenti', RegExp(r'^Spostato in cima: (.*) \(\d+ vo'),
      (m) => '"${m[1]}" è tornato in cima ai file recenti.'),
  _Say('Recenti', RegExp(r'^Aggiunto: (.*) \(\d+ vo'),
      (m) => '"${m[1]}" è stato aggiunto ai file recenti.'),
  _Say('Recenti', RegExp(r'^Rinominato: (.*) \(\d+ vo'),
      (m) => 'Nei file recenti un documento è stato rinominato "${m[1]}".'),
  _Say('Recenti', RegExp(r'^Tolto dall.elenco'),
      (m) => 'Un file è stato tolto dai file recenti.'),
  _Say('Recenti', RegExp(r'^Elenco svuotato'),
      (m) => 'L\'elenco dei file recenti è stato svuotato.'),
  _Say('Recenti', RegExp(r'^Passati al formato nuovo'),
      (m) => 'L\'elenco dei file recenti è stato convertito nel formato '
          'nuovo, che salva un file alla volta.'),
  _Say('Recenti', RegExp(r'^Percorso della copia aggiornato'),
      (m) => 'Dopo un aggiornamento dell\'app ho ricollegato la copia di un '
          'file recente.'),
  _Say('Recenti', RegExp(r'^Disponibilit.{1,2} della copia aggiornata'),
      (m) => 'Ho controllato quali copie dei file recenti sono ancora '
          'disponibili.'),
  _Say('Recenti', RegExp(r'^Caricamento non riuscito'),
      (m) => 'Non sono riuscito a leggere l\'elenco dei file recenti.'),
  _Say('Recenti', RegExp(r'^Salvataggio non riuscito'),
      (m) => 'Non sono riuscito a salvare l\'elenco dei file recenti.'),
  // OCR
  _Say('OCR', RegExp(r'^"(.*)": ha gi.{1,2} un livello di testo'),
      (m) => 'Il documento "${m[1]}" ha già un livello di testo: non serviva '
          'fare l\'OCR.'),
  _Say('OCR', RegExp(r'^"(.*)": non in memoria'),
      (m) => 'Per "${m[1]}" il testo OCR non era in memoria: parte la '
          'scansione del documento.'),
  _Say('OCR', RegExp(r'^"(.*)": testo preso dalla memoria'),
      (m) => 'Per "${m[1]}" ho riusato il testo già riconosciuto: scansione '
          'non rifatta.'),
  // Salvataggio e cartella
  _Say('Salvataggio documento', RegExp(r'^Salvato "(.*)"$'),
      (m) => 'Il documento "${m[1]}" è stato salvato.'),
  _Say('Salvataggio documento',
      RegExp(r'^Non riuscito sul file originale "(.*)":'),
      (m) => 'Non sono riuscito a salvare "${m[1]}" sul file originale.'),
  _Say('Salvataggio documento', RegExp(r'^Scritto "(.*)" nella cartella "(.*)"$'),
      (m) => '"${m[1]}" è stato salvato nella cartella "${m[2]}".'),
  _Say('Cartella di salvataggio', RegExp(r'^Impostata: (.*)$'),
      (m) => 'Hai scelto "${m[1]}" come cartella di salvataggio.'),
  _Say('Cartella di salvataggio', RegExp(r'^Rimossa$'),
      (m) => 'Hai tolto la cartella di salvataggio.'),
  // Stampa
  _Say('Stampa', RegExp(r'^Fogli stampati come a schermo'),
      (m) => 'I fogli sono stati preparati per la stampa così come li vedi a '
          'schermo (300 dpi).'),
  _Say('Stampa', RegExp(r'^Immagine non riuscita'),
      (m) => 'Non sono riuscito a preparare i fogli per la stampa.'),
  // Aggiornamenti
  _Say('Aggiornamenti',
      RegExp(r'^Inizio aggiornamento: dalla build (\S+) alla (\S+)'),
      (m) => 'È iniziato l\'aggiornamento dalla build ${m[1]} alla ${m[2]}.'),
  _Say('Aggiornamenti', RegExp(r'^Aggiornamento annullato'),
      (m) => 'Hai annullato l\'aggiornamento.'),
  _Say('Aggiornamenti', RegExp(r'^Aggiornamento scaricato e passato'),
      (m) => 'L\'aggiornamento è stato scaricato ed è passato '
          'all\'installazione di Android.'),
  _Say('Aggiornamenti', RegExp(r'^Aggiornamento (con patch )?non riuscito'),
      (m) => 'L\'aggiornamento non è riuscito.'),
  // WhatsApp
  _Say('Contatti WhatsApp', RegExp(r'^Salvati (\d+) contatti'),
      (m) => 'Ho salvato ${m[1]} contatti WhatsApp.'),
  _Say('Invio WhatsApp', RegExp(r'^"(.*)" inviato a (.*)$'),
      (m) => '"${m[1]}" è stato inviato a ${m[2]} su WhatsApp.'),
];

/// Cosa e' successo quando una voce di errore non ha una frase sua, in base
/// all'argomento.
const Map<String, String> _errorByContext = {
  'Invio WhatsApp': 'L\'invio su WhatsApp non è riuscito.',
  'Salvataggio documento': 'Non sono riuscito a salvare il documento.',
  'Cartella di salvataggio':
      'Non sono riuscito a impostare la cartella di salvataggio.',
  'Stampa': 'La stampa non è riuscita.',
  'Aggiornamenti': 'L\'aggiornamento non è riuscito.',
  'Recenti': 'C\'è stato un problema con l\'elenco dei file recenti.',
  'Errore interno': 'L\'app ha avuto un errore interno.',
  'Errore dell\'app': 'L\'app ha avuto un errore imprevisto.',
  'Errore non gestito': 'L\'app ha avuto un errore imprevisto.',
};

/// Una frase in italiano che dice cosa e' successo in una voce del Log.
String describeLogEntry(AppLogEntry e) {
  final first = e.message.split('\n').first.trim();
  for (final say in _says) {
    if (say.context != e.context) continue;
    final m = say.pattern.firstMatch(first);
    if (m != null) return say.build(m);
  }
  if (e.level == AppLogLevel.errore) {
    return _errorByContext[e.context] ??
        'Si è verificato un problema durante "${e.context}".';
  }
  return first.isEmpty ? e.context : first;
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
  bool _saving = false;
  bool _dirty = false;
  bool _loaded = false;

  /// Vero quando il Log salvato e' stato letto: prima di allora non si
  /// scrive su disco, per non cancellare le voci precedenti.
  bool _ready = false;
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
      if (raw == null) {
        _markReady();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _markReady();
        return;
      }
      final saved = [
        for (final m in decoded.whereType<Map>())
          AppLogEntry.fromJson(m.cast<String, dynamic>()),
      ];
      _entries.insertAll(0, saved);
      _trim();
      notifyListeners();
      _markReady();
    } catch (e) {
      persistFailed = true;
      _add(AppLogLevel.errore, 'Log',
          'Lettura del Log salvato non riuscita: $e');
      _markReady();
    }
  }

  void _markReady() {
    _ready = true;
    if (_entries.isNotEmpty) _scheduleSave();
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
      b.writeln('Cosa è successo: ${describeLogEntry(e)}');
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
    if (!_ready) return;
    _dirty = true;
    if (_saving) return;
    _saving = true;
    scheduleMicrotask(_drain);
  }

  /// Scrive su disco, riunendo in una sola scrittura le voci arrivate
  /// mentre quella precedente era in corso.
  Future<void> _drain() async {
    while (_dirty) {
      _dirty = false;
      await _save();
    }
    _saving = false;
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
