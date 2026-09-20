import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terminal_agent/models/db_connection_profile.dart';
import 'package:terminal_agent/services/backup_service.dart';

DbConnectionProfile _profile({String password = 'hunter2'}) =>
    DbConnectionProfile(
      id: 'db1',
      sshProfileId: 'srv1',
      name: 'main',
      engine: 'postgres',
      host: 'localhost',
      port: 5432,
      username: 'admin',
      password: password,
      databaseName: 'app',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DbConnectionProfile secret split', () {
    test('toJsonPublic leaves the password out; toJson keeps it', () {
      final public =
          json.decode(_profile().toJsonPublic()) as Map<String, dynamic>;
      expect(public.containsKey('password'), isFalse);
      expect(public['username'], 'admin');
      expect(public['port'], 5432);
      final full = json.decode(_profile().toJson()) as Map<String, dynamic>;
      expect(full['password'], 'hunter2');
    });

    test('fromMap round-trips a public map (password empty, not missing)',
        () {
      final public =
          json.decode(_profile().toJsonPublic()) as Map<String, dynamic>;
      final p = DbConnectionProfile.fromMap(public);
      expect(p.id, 'db1');
      expect(p.engine, 'postgres');
      expect(p.password, isEmpty);
    });

    test('copyWith(password:) reattaches the resolved secret', () {
      final bare = _profile(password: '');
      expect(bare.copyWith(password: 'from-store').password, 'from-store');
      // null keeps what was there.
      expect(bare.copyWith().password, isEmpty);
    });
  });

  group('BackupService with db_profiles', () {
    test('db_profiles is backed up, and password-less at that', () async {
      SharedPreferences.setMockInitialValues({
        'db_profiles': <String>[_profile().toJsonPublic()],
      });
      final envelope = await BackupService.build(includeSecrets: false);
      final prefs = envelope['prefs'] as Map<String, dynamic>;
      expect(prefs.containsKey('db_profiles'), isTrue);
      expect(json.encode(prefs['db_profiles']['value']),
          isNot(contains('hunter2')));
    });

    test('restore writes db_profiles back', () async {
      SharedPreferences.setMockInitialValues({
        'db_profiles': <String>[_profile().toJsonPublic()],
      });
      final envelope = await BackupService.build(includeSecrets: false);

      SharedPreferences.setMockInitialValues({});
      final result = await BackupService.restore(envelope);
      expect(result.error, isNull);
      expect(result.keys, greaterThan(0));

      final prefs = await SharedPreferences.getInstance();
      final restored = prefs.getStringList('db_profiles') ?? const [];
      expect(restored, hasLength(1));
      expect(
          (json.decode(restored.first) as Map<String, dynamic>)['id'], 'db1');
    });
  });
}
