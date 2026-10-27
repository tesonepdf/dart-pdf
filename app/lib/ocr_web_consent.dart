import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that the user approved running browser-local OCR.
class OcrWebConsent {
  static const _key = 'dart_pdf_editor_app.ocr.web.consent';

  bool _approved = false;
  Future<void>? _loading;

  bool get approved => _approved;

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _approved = prefs.getBool(_key) ?? false;
    } catch (error) {
      debugPrint('Web OCR consent unreadable: $error');
    }
  }

  Future<void> approve() async {
    _approved = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (error) {
      debugPrint('Web OCR consent not saved: $error');
    }
  }
}
