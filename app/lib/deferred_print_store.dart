// L'archivio della stampa differita: file su disco dove c'e' dart:io,
// IndexedDB nel browser (web).
export 'deferred_print_store_stub.dart'
    if (dart.library.io) 'deferred_print_store_io.dart'
    if (dart.library.js_interop) 'deferred_print_store_web.dart';
