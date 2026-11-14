import 'deferred_print.dart';

/// Senza disco (web): i gruppi restano in memoria finche' l'app e' aperta.
final DeferredPrintStore _shared = MemoryDeferredPrintStore();

DeferredPrintStore openDeferredPrintStore() => _shared;
