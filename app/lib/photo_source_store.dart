// Dove si ricorda la foto da cui nasce un documento aperto come foto, cosi'
// "Misura della foto" resta disponibile anche dopo aver chiuso e riaperto
// l'app: file su disco dove c'e' dart:io, IndexedDB nel browser (web), niente
// altrove. La foto e' legata ai byte del PDF che ne e' nato (vedi
// `pdfContentKey`): se il documento viene modificato e salvato i byte
// cambiano e la foto non si ritrova piu'.
export 'photo_source_store_stub.dart'
    if (dart.library.io) 'photo_source_store_io.dart'
    if (dart.library.js_interop) 'photo_source_store_web.dart';
