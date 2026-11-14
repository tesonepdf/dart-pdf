// Dove si conserva la cronologia annulla/ripeti di un documento: file su
// disco dove c'e' dart:io, IndexedDB nel browser (web).
export 'edit_history_store_base.dart';
export 'edit_history_store_stub.dart'
    if (dart.library.io) 'edit_history_store_io.dart'
    if (dart.library.js_interop) 'edit_history_store_web.dart';
