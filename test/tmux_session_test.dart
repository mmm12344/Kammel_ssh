import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_agent/models/tmux_session.dart';

void main() {
  group('TmuxSession.parseLs', () {
    test('parses one session per line with the five fields', () {
      final sessions = TmuxSession.parseLs(
          '2|3|/srv/api|vim|kammel-prod\n0|1|/home/me||agent-session\n');
      expect(sessions, hasLength(2));
      expect(sessions[0].name, 'kammel-prod');
      expect(sessions[0].attachedClients, 2);
      expect(sessions[0].isAttached, isTrue);
      expect(sessions[0].windows, 3);
      expect(sessions[0].path, '/srv/api');
      expect(sessions[0].command, 'vim');
      expect(sessions[1].name, 'agent-session');
      expect(sessions[1].isAttached, isFalse);
      expect(sessions[1].command, isEmpty);
    });

    test('a session name may contain pipes — it is rebuilt, not split', () {
      final sessions = TmuxSession.parseLs('0|1|/root||we|ird|name');
      expect(sessions, hasLength(1));
      expect(sessions.single.name, 'we|ird|name');
    });

    test('drops lines with fewer than the five fields', () {
      // e.g. a warning or another tool's output sharing the channel.
      expect(TmuxSession.parseLs('no server running on /tmp/tmux-0/default'),
          isEmpty);
      expect(TmuxSession.parseLs('0|1|/root|name-only-three'), isEmpty);
    });

    test('tolerates CRLF and blank lines', () {
      final sessions = TmuxSession.parseLs('\r\n0|1|/tmp||x\r\n\r\n');
      expect(sessions, hasLength(1));
      expect(sessions.single.name, 'x');
    });

    test('non-numeric counts fall back to detached/single-window', () {
      final sessions = TmuxSession.parseLs('?|?|/tmp||odd');
      expect(sessions.single.attachedClients, 0);
      expect(sessions.single.windows, 1);
    });

    test('empty output yields an empty list', () {
      expect(TmuxSession.parseLs(''), isEmpty);
    });
  });

  group('TmuxSession commands', () {
    test('listCommand asks for the five fields with the name last', () {
      final cmd = TmuxSession.listCommand();
      expect(cmd, startsWith('tmux ls -F \''));
      expect(cmd, endsWith('{session_name}\''));
      // The fixed fields come before the name, so a name with pipes survives
      // parsing (rebuilt from the extras).
      expect(cmd.indexOf('{session_name}'),
          greaterThan(cmd.indexOf('{pane_current_command}')));
    });

    test('attachCommand single-quotes the name', () {
      expect(TmuxSession(name: 'api').attachCommand(),
          "tmux new-session -A -s 'api'");
      // A quote in a tmux session name must not break out of the quoting.
      expect(TmuxSession(name: "it's").attachCommand(),
          r"tmux new-session -A -s 'it'\''s'");
    });

    test('shQuote round-trips arbitrary values through a POSIX shell', () {
      // Trailing backslash: the classic quoting killer.
      expect(TmuxSession.shQuote(r'odd\'), r"'odd\'");
    });
  });

  group('TmuxAutostart.ensurePlan', () {
    test('only the sessions that do not exist yet get created', () {
      final plan = TmuxAutostart.ensurePlan(
        {'api', 'kammel-web'},
        const [
          TmuxAutostart(name: 'api', path: '/srv/api'),
          TmuxAutostart(name: 'worker', path: '/srv/worker'),
        ],
      );
      expect(plan, hasLength(1));
      expect(plan.single.name, 'worker');
    });

    test('an existing session is never re-created — even with another path',
        () {
      // The point of the feature: whatever the server already has under that
      // name (a running agent, the user's own session) is left alone.
      expect(
          TmuxAutostart.ensurePlan({'api'}, const [
            TmuxAutostart(name: 'api', path: '/somewhere/else'),
          ]),
          isEmpty);
    });

    test('duplicate names in the list deduplicate, first entry wins', () {
      final plan = TmuxAutostart.ensurePlan(const {}, const [
        TmuxAutostart(name: 'api', path: '/first'),
        TmuxAutostart(name: 'api', path: '/second'),
      ]);
      expect(plan, hasLength(1));
      expect(plan.single.path, '/first');
    });

    test('blank names drop out', () {
      expect(
          TmuxAutostart.ensurePlan(const {}, const [
            TmuxAutostart(name: '  '),
            TmuxAutostart(name: ''),
          ]),
          isEmpty);
    });

    test('names are compared trimmed', () {
      final plan = TmuxAutostart.ensurePlan({'api'}, const [
        TmuxAutostart(name: '  api  '),
      ]);
      expect(plan, isEmpty);
    });
  });

  group('TmuxAutostart.createCommand', () {
    test('creates detached at the start directory', () {
      expect(const TmuxAutostart(name: 'api', path: '/srv/api').createCommand(),
          "tmux new-session -d -s 'api' -c '/srv/api'");
    });

    test('without a path it omits -c entirely', () {
      expect(const TmuxAutostart(name: 'api').createCommand(),
          "tmux new-session -d -s 'api'");
    });

    test('names and paths with quotes are shell-quoted', () {
      final cmd = const TmuxAutostart(name: "it's", path: "/a b/c").createCommand();
      expect(cmd, contains(r"-s 'it'\''s'"));
      expect(cmd, contains("-c '/a b/c'"));
    });
  });
}
