// L'archivio della stampa differita: file su disco dove c'e' dart:io, in
// memoria altrove (web).
export 'deferred_print_store_stub.dart'
    if (dart.library.io) 'deferred_print_store_io.dart';
