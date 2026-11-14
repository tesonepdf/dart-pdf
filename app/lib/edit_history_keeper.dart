import 'dart:async';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart'
    show PdfEditingController, PdfEditHistorySnapshot;

import 'app_log.dart';
import 'document_tab.dart';
import 'edit_history_store.dart';

/// Quanto deve restare ferma la modifica prima di salvare la cronologia.
const Duration _kHistoryDebounce = Duration(milliseconds: 1500);

/// Fa si' che annulla e ripeti restino con il documento anche dopo aver
/// chiuso l'app.
///
/// Ogni modifica, annulla o ripeti salva (dopo una breve pausa) la cronologia
/// del documento; quando un documento si apre, se esiste la cronologia di
/// quei byte esatti, la si rimette. La cronologia e' legata al contenuto del
/// file (vedi [EditHistoryStore]), non al nome: un file diverso non la
/// riceve mai.
class EditHistoryKeeper {
  EditHistoryKeeper({
    EditHistoryStore? store,
    this.debounce = _kHistoryDebounce,
  }) : _store = store;

  final EditHistoryStore? _store;
  final Duration debounce;

  final Map<DocumentTab, _Tracked> _tracked = {};

  bool get enabled => _store != null;

  /// Segue ogni scheda modificabile aperta e lascia quelle chiuse. Si chiama
  /// ogni volta che cambia l'insieme delle schede.
  void syncTracking(Iterable<DocumentTab> tabs) {
    if (_store == null) return;
    final live = tabs.toSet();
    for (final tab in _tracked.keys.toList()) {
      final tracked = _tracked[tab]!;
      if (!live.contains(tab) || !identical(tab.session, tracked.session)) {
        _untrack(tab);
      }
    }
    for (final tab in live) {
      if (tab.session != null) _track(tab);
    }
  }

  void _track(DocumentTab tab) {
    final session = tab.session;
    if (_store == null || session == null || _tracked.containsKey(tab)) return;
    final tracked = _Tracked(session, session.revisionId);
    _tracked[tab] = tracked;
    tracked.listener = () => _onChanged(tab);
    session.addListener(tracked.listener!);
    unawaited(_restore(tab, session));
  }

  void _untrack(DocumentTab tab) {
    final tracked = _tracked.remove(tab);
    if (tracked == null) return;
    tracked.debounce?.cancel();
    final listener = tracked.listener;
    if (listener != null) tracked.session.removeListener(listener);
  }

  /// Rimette la cronologia salvata, se c'e' quella di questi byte.
  Future<void> _restore(DocumentTab tab, PdfEditingController session) async {
    final store = _store;
    if (store == null) return;
    try {
      // solo su un documento appena aperto e ancora senza modifiche
      if (session.revisionCount != 1) return;
      final snapshot = await store.load(session.bytes);
      if (snapshot == null) return;
      if (!identical(tab.session, session)) return;
      if (session.restoreHistory(snapshot)) {
        AppLog.instance.ok('Annulla e ripeti',
            'Ripristinata la cronologia di "${tab.title}" (${snapshot.undoSteps} da annullare, ${snapshot.redoSteps} da ripetere)');
      }
    } catch (error, stack) {
      AppLog.instance.error('Annulla e ripeti', '$error', stack);
    }
  }

  void _onChanged(DocumentTab tab) {
    final tracked = _tracked[tab];
    if (tracked == null) return;
    final id = tracked.session.revisionId;
    // il controller avvisa anche per una selezione o uno zoom: conta solo
    // quando e' cambiata la revisione (modifica, annulla, ripeti)
    if (id == tracked.seenRevision) return;
    tracked.seenRevision = id;
    tracked.debounce?.cancel();
    tracked.debounce = Timer(debounce, () => unawaited(_write(tab)));
  }

  Future<void> _write(DocumentTab tab) async {
    final store = _store;
    final tracked = _tracked[tab];
    if (store == null || tracked == null) return;
    tracked.debounce = null;
    final session = tracked.session;
    if (!identical(tab.session, session)) return;
    if (tracked.writing) {
      tracked.pending = true;
      return;
    }
    final snapshot = session.historySnapshot;
    if (snapshot == null) return;
    // la revisione corrente: un prefisso stabile del buffer, che non cambia
    // finche' non arriva un'altra modifica
    final Uint8List bytes = session.bytes;
    tracked.writing = true;
    try {
      final key = await store.save(bytes, snapshot);
      if (key != null) {
        final previous = tracked.lastKey;
        final previousLength = tracked.lastLength;
        tracked.lastKey = key;
        tracked.lastLength = bytes.length;
        // Lo stato intermedio non salvato si butta; lo stato salvato sul file
        // resta, perche' il file riaperto lo ritrova.
        if (previous != null &&
            previous != key &&
            previousLength != tab.savedLength) {
          await store.remove(previous);
        }
      }
    } catch (error, stack) {
      AppLog.instance.error('Annulla e ripeti', '$error', stack);
    } finally {
      tracked.writing = false;
    }
    if (tracked.pending) {
      tracked.pending = false;
      if (_tracked[tab] == tracked) unawaited(_write(tab));
    }
  }

  /// Salva subito quello che e' in attesa, senza aspettare la pausa. Si
  /// chiama quando l'app va in secondo piano: su telefono puo' essere l'ultima
  /// occasione.
  Future<void> flushPending() async {
    for (final tab in _tracked.keys.toList()) {
      final tracked = _tracked[tab];
      if (tracked == null || tracked.debounce == null) continue;
      tracked.debounce!.cancel();
      await _write(tab);
    }
  }

  /// Smette di seguire le schede; quello che e' su disco resta.
  void dispose() {
    for (final tab in _tracked.keys.toList()) {
      _untrack(tab);
    }
  }
}

class _Tracked {
  _Tracked(this.session, this.seenRevision);

  final PdfEditingController session;
  int seenRevision;
  void Function()? listener;
  Timer? debounce;
  bool writing = false;
  bool pending = false;
  String? lastKey;
  int lastLength = -1;
}
