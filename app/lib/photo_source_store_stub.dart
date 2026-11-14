import 'dart:typed_data';

/// Senza archivio: la foto non si ricorda.
Future<void> rememberPhotoSource(Uint8List pdfBytes, Uint8List photo) async {}

/// Senza archivio: nessuna foto da ritrovare.
Future<Uint8List?> recallPhotoSource(Uint8List pdfBytes) async => null;
