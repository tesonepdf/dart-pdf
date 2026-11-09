import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'devtools.dart';
import 'pdf_cache.dart';

/// One file-backed document that was open in the previous session, captured so
/// the editor can re-open it on the next launch.
@immutable
class SessionDocument {
  const SessionDocument({
    required this.title,
    required this.path,
    this.cachePath,
    this.bookmark,
  });

  /// The tab title (usually the file name) - shown while the file is read back.
  final String title;

  /// The reusable on-disk origin (desktop), or empty for a mobile pick tracked
  /// only by its [cachePath] snapshot.
  final String path;

  /// The app-private snapshot of a mobile pick's bytes (see pdf_cache.dart),
  /// so the last session restores there too even without a durable [path].
  final String? cachePath;

  /// macOS security-scoped bookmark for [path], when available.
  final String? bookmark;

  /// Where to read the document back from - the real origin when present,
  /// otherwise the private snapshot. Null when neither is usable.
  String? get readPath {
    if (path.isNotEmpty) return path;
    if (cachePath != null && cachePath!.isNotEmpty) return cachePath;
    return null;
  }

  Map<String, dynamic> toJson() => {
        't': title,
        'p': path,
        if (cachePath != null) 'c': cachePath,
        if (bookmark != null) 'b': bookmark,
      };

  factory SessionDocument.fromJson(Map<String, dynamic> j) => SessionDocument(
        title: (j['t'] as String?) ?? 'Untitled',
        path: (j['p'] as String?) ?? '',
        cachePath: j['c'] as String?,
        bookmark: j['b'] as String?,
      );
}

/// Persists the ordered list of file-backed documents currently open so the
/// editor can re-open them the next time it launches ("restore last session").
///
/// Documents are tracked by a reusable read source - the on-disk path on
/// desktop, or the app-private byte snapshot on mobile (private file) and web
/// (IndexedDB), see pdf_cache.dart. A derived tab (comparison, or a pick whose
/// snapshot failed) has neither and is skipped. Backed by `shared_preferences`;
/// when storage is unavailable (widget tests) it degrades to the in-memory
/// list, mirroring how [RecentsStore] and [PdfEditingPreferences] handle the
/// same case.
class SessionStore {
  SessionStore({CachedPdfKeyResolver? resolveCacheKey})
      : _resolveCacheKey = resolveCacheKey ?? resolveCachedPdfKey;

  final CachedPdfKeyResolver _resolveCacheKey;

  static const _key = 'dart_pdf_editor_app.session';
  static const _activeKey = 'dart_pdf_editor_app.session_active';
  static const _pagesKey = 'dart_pdf_editor_app.session_pages';

  /// Ultima pagina in vista per documento (chiave: percorso o copia privata).
  Map<String, int> _pages = const {};
  Map<String, int> get pages => _pages;

  Future<void> savePages(Map<String, int> pages) async {
    _pages = Map.unmodifiable(pages);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pagesKey, jsonEncode(pages));
    } catch (_) {}
  }

  /// Posizione (nell'elenco dei documenti) di quello che si stava guardando.
  int _activeIndex = 0;
  int get activeIndex => _activeIndex;

  List<SessionDocument> _documents = const [];

  /// The most recently loaded/saved set of open documents, in tab order.
  List<SessionDocument> get documents => List.unmodifiable(_documents);

  /// Reads the persisted open-document list. Returns the (possibly empty) list
  /// and also caches it in [documents].
  Future<List<SessionDocument>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // -1: nessuna scelta salvata (sessione vecchia), resta attiva l'ultima scheda
      _activeIndex = prefs.getInt(_activeKey) ?? -1;
      try {
        final rawPages = prefs.getString(_pagesKey);
        if (rawPages != null) {
          final m = jsonDecode(rawPages);
          if (m is Map) {
            _pages = {
              for (final e in m.entries)
                if (e.value is int) e.key as String: e.value as int
            };
          }
        }
      } catch (_) {}
      final raw = prefs.getString(_key);
      if (raw == null) return _documents;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _documents;
      _documents = [
        for (final m in decoded.whereType<Map>())
          await _rebase(SessionDocument.fromJson(m.cast<String, dynamic>())),
      ].where((d) => d.readPath != null).toList();
    } catch (e) {
      // No storage (tests) - keep whatever is already in memory.
      AppDevTools.instance
          .addLog('session restore failed: $e', level: DevLogLevel.error);
    }
    return _documents;
  }

  /// Points [doc]'s snapshot at the live store, which an app update can move
  /// (see `resolveCachedPdfKey`).
  Future<SessionDocument> _rebase(SessionDocument doc) async {
    final cachePath = doc.cachePath;
    if (cachePath == null) return doc;
    final live = await _resolveCacheKey(cachePath);
    if (live == null || live == cachePath) return doc;
    return SessionDocument(
        title: doc.title,
        path: doc.path,
        cachePath: live,
        bookmark: doc.bookmark);
  }

  /// Replaces the persisted open-document list with [documents] (tab order).
  Future<void> save(List<SessionDocument> documents,
      {int activeIndex = 0}) async {
    _documents = List.unmodifiable(documents);
    _activeIndex = activeIndex;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_activeKey, activeIndex);
      await prefs.setString(
          _key, jsonEncode(_documents.map((d) => d.toJson()).toList()));
    } catch (e) {
      // No storage - nothing to persist.
      AppDevTools.instance
          .addLog('session persist failed: $e', level: DevLogLevel.error);
    }
  }
}
