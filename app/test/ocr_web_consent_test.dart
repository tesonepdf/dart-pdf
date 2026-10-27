import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/ocr_web_consent.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('consent is false until approved', () async {
    final consent = OcrWebConsent();

    await consent.load();

    expect(consent.approved, isFalse);
  });

  test('approval persists across app instances', () async {
    final consent = OcrWebConsent();
    await consent.load();
    await consent.approve();

    final nextLaunch = OcrWebConsent();
    await nextLaunch.load();

    expect(nextLaunch.approved, isTrue);
  });
}
