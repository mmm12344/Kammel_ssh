import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terminal_agent/l10n/l10n.dart';
import 'package:terminal_agent/models/terminal_shortcut.dart';
import 'package:terminal_agent/providers/app_state.dart';

String _encode(List<TerminalShortcut> list) =>
    json.encode(list.map((s) => s.toJson()).toList());

Future<AppState> _state() async {
  L10n.notifier.value = AppLang.es;
  await L10n.load();
  final state = AppState();
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return state;
}

/// Migration v4.
///
/// The shortcuts that moved into the built-in rows and layers used to be
/// cleaned up by resetting the user's whole list to defaults, throwing away
/// every rename and custom key along with the duplicates. It now removes only
/// entries still byte-identical to the old defaults.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('byte-identical duplicates are dropped, user edits survive', () async {
    final owned = [
      // Still identical to an old default → removed.
      TerminalShortcut(label: '^W', value: r'\x17'),
      // Same value, renamed → the user's entry, kept.
      TerminalShortcut(label: 'borrar palabra', value: r'\x17'),
      // Same label, different value → kept.
      TerminalShortcut(label: '^C', value: r'\x03\x03'),
      // Plainly the user's own → kept.
      TerminalShortcut(label: 'mi cosa', value: 'htop\\n'),
    ];
    SharedPreferences.setMockInitialValues({
      'settings_custom_shortcuts_json': _encode(owned),
      // v3 already ran (defaults appended); v4 has not.
      'settings_shortcuts_migrated_v3': true,
    });
    final state = await _state();

    final values = state.myShortcuts.map((s) => s.value).toList();
    final labels = state.myShortcuts.map((s) => s.label).toList();
    // The byte-identical duplicate is gone…
    expect(values.where((v) => v == r'\x17').length, 1,
        reason: 'only the renamed entry survives');
    expect(labels, contains('borrar palabra'));
    expect(labels, contains('mi cosa'));
    // …and a ^C whose value the user changed is not the default anymore.
    expect(values, contains(r'\x03\x03'));
  });

  test('a list that is exactly the old default converges on the new one',
      () async {
    final oldDefaults = [
      TerminalShortcut(label: 'Re Pág', value: r'\x1b[5~'),
      TerminalShortcut(label: 'Av Pág', value: r'\x1b[6~'),
      TerminalShortcut(label: 'Inicio', value: r'\x1b[H'),
      TerminalShortcut(label: 'Fin', value: r'\x1b[F'),
      TerminalShortcut(label: '^C', value: r'\x03'),
      TerminalShortcut(label: '^D', value: r'\x04'),
      TerminalShortcut(label: '^DEL', value: r'\x1b[3;5~'),
      TerminalShortcut(label: 'S-Tab', value: r'\x1b[Z'),
      TerminalShortcut(label: '^O', value: r'\x0f'),
      TerminalShortcut(label: '^G', value: r'\x07'),
      TerminalShortcut(label: '^L', value: r'\x0c'),
      TerminalShortcut(label: '^R', value: r'\x12'),
      TerminalShortcut(label: '^W', value: r'\x17'),
      TerminalShortcut(label: '^J', value: r'\n'),
      TerminalShortcut(label: '^U', value: r'\x15'),
      TerminalShortcut(label: 'clear', value: 'clear\n'),
    ];
    SharedPreferences.setMockInitialValues({
      'settings_custom_shortcuts_json': _encode(oldDefaults),
      'settings_shortcuts_migrated_v3': true,
    });
    final state = await _state();

    // Everything the layers now cover is gone; the user's own row keeps
    // nothing but the entries that were never duplicated elsewhere.
    final labels = state.myShortcuts.map((s) => s.label).toList();
    expect(labels, contains('clear'));
    expect(labels, isNot(contains('Re Pág')));
    expect(labels, isNot(contains('S-Tab')));
    expect(labels, isNot(contains('^U')));
  });
}
