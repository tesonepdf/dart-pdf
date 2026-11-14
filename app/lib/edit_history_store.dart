// Dove si conserva la cronologia annulla/ripeti di un documento: file su
// disco dove c'e' dart:io, niente altrove (web).
export 'edit_history_store_base.dart';
export 'edit_history_store_stub.dart'
    if (dart.library.io) 'edit_history_store_io.dart';
