import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terminal_agent/l10n/l10n.dart';
import 'package:terminal_agent/models/connection_profile.dart';
import 'package:terminal_agent/providers/app_state.dart';

/// Duplicating a profile.
///
/// A duplicate is a *new machine that starts out the same*: if it silently
/// dropped the signal color, the production flag or the jump host, the user
/// would get a look-alike profile that behaves differently — a production
/// bastion duplicated without its jump chain can never connect at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Secure storage has no shared_preferences-style mock; answer the
    // platform channel directly so saveProfile can store (empty) secrets.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    SharedPreferences.setMockInitialValues({});
    L10n.notifier.value = AppLang.es;
  });

  test('the duplicate keeps color, production flag and jump host', () async {
    SharedPreferences.setMockInitialValues({});
    L10n.notifier.value = AppLang.es;
    await L10n.load();
    final state = AppState();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final bastion = ConnectionProfile(
      id: 'bastion',
      name: 'bastion',
      host: '10.0.0.1',
      port: 22,
      username: 'ops',
      colorHex: '#E63946',
      isProduction: true,
    );
    final target = ConnectionProfile(
      id: 'target',
      name: 'db',
      host: '10.0.0.2',
      port: 22,
      username: 'ops',
      colorHex: '#0055FF',
      isProduction: true,
      jumpProfileId: 'bastion',
    );
    await state.saveProfile(bastion);
    await state.saveProfile(target);

    final copy = await state.duplicateProfile(target);
    expect(copy.id, isNot('target'));
    expect(copy.name, 'db (copia)');
    expect(copy.colorHex, '#0055FF');
    expect(copy.isProduction, isTrue);
    expect(copy.jumpProfileId, 'bastion');
    expect(copy.host, '10.0.0.2');
    expect(copy.tunnels, isEmpty);
  });
}
