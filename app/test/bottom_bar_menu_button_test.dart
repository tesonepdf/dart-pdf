// Il pulsante del menu che fa comparire anche la barra in basso nascosta.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_pdf_editor_app/bottom_bar_setting.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BottomBarSetting.instance.value = false;
    BottomBarMenuButtonSetting.instance.value = false;
    BottomBarPeek.visible.value = false;
  });

  test('di base la scelta e\' spenta: il pulsante non mostra la barra', () {
    BottomBarPeek.onMenuButton();
    expect(BottomBarPeek.visible.value, isFalse);
  });

  test('con la scelta accesa il pulsante mostra e poi nasconde la barra',
      () async {
    await BottomBarMenuButtonSetting.instance.save(true);
    BottomBarPeek.onMenuButton();
    expect(BottomBarPeek.visible.value, isTrue);
    BottomBarPeek.onMenuButton();
    expect(BottomBarPeek.visible.value, isFalse);
  });

  test('con la barra sempre visibile il pulsante non cambia niente', () async {
    await BottomBarMenuButtonSetting.instance.save(true);
    await BottomBarSetting.instance.save(true);
    BottomBarPeek.onMenuButton();
    expect(BottomBarPeek.visible.value, isFalse);
  });

  test('la scelta si salva sul dispositivo', () async {
    await BottomBarMenuButtonSetting.instance.save(true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dart_pdf_editor_app.bottom_bar_menu_button'), isTrue);
  });
}
