import 'package:flutter/widgets.dart';

import 'ocr_background.dart';

/// Pause between pages when the app is no longer visible. A transient loss of
/// focus (inactive) still permits foreground work, such as a desktop dialog.
///
/// Su Android, mentre il servizio in primo piano dell'OCR è attivo
/// ([OcrBackgroundService.active]) il lavoro continua anche con l'app in
/// secondo piano: la pausa vale solo quando il servizio non c'è.
bool get ocrShouldPause {
  if (OcrBackgroundService.active) return false;
  return switch (WidgetsBinding.instance.lifecycleState) {
    AppLifecycleState.paused ||
    AppLifecycleState.hidden ||
    AppLifecycleState.detached =>
      true,
    _ => false,
  };
}
