/// A tmux session that exists on a server, as `tmux ls -F` reports it.
///
/// Pure data and pure parsing, kept out of `AppState` so the discovery feature
/// is testable without an SSH connection — the same split as `JumpChain` and
/// `GitRepoInfo`.
class TmuxSession {
  final String name;

  /// Clients currently attached to it. 0 is tmux's "detached".
  final int attachedClients;
  final int windows;

  /// Working directory of the session's active pane ('' when tmux is too old
  /// to report it).
  final String path;

  /// Command running in the session's active pane ('' when it is a bare
  /// shell prompt). A hint of what the session is doing, not a promise.
  final String command;

  const TmuxSession({
    required this.name,
    this.attachedClients = 0,
    this.windows = 1,
    this.path = '',
    this.command = '',
  });

  bool get isAttached => attachedClients > 0;

  /// Parses the output of [listCommand]: one session per line, five `|`
  /// separated fields.
  ///
  /// The session *name* goes last and is rebuilt from any extra separators:
  /// tmux only forbids `:` and `.` in names, so a name may legally contain a
  /// pipe — the four fixed fields never do. Lines that don't have at least
  /// five fields (warnings, other tools' output on a shared channel) are
  /// dropped rather than guessed at.
  static List<TmuxSession> parseLs(String output) {
    final sessions = <TmuxSession>[];
    for (final rawLine in output.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      final parts = line.split('|');
      if (parts.length < 5) continue;
      final name = parts.sublist(4).join('|').trim();
      if (name.isEmpty) continue;
      sessions.add(TmuxSession(
        name: name,
        attachedClients: int.tryParse(parts[0]) ?? 0,
        windows: int.tryParse(parts[1]) ?? 1,
        path: parts[2],
        command: parts[3],
      ));
    }
    return sessions;
  }

  /// The remote command discovery runs. One line per session on stdout;
  /// "no server running" is exit status 1 on stderr, which the caller reads
  /// as an empty list. Single-quoted, so the shell never touches the format.
  static String listCommand() =>
      "tmux ls -F '#{session_attached}|#{session_windows}|"
      "#{pane_current_path}|#{pane_current_command}|#{session_name}'";

  /// The command a terminal runs to join this session. `new-session -A`
  /// attaches when it exists and re-creates it otherwise, so joining a
  /// session that died while the user was looking at the list repairs
  /// itself instead of dead-ending in an error.
  String attachCommand() => 'tmux new-session -A -s ${shQuote(name)}';

  /// Single-quote a value for a POSIX shell, safe against embedded quotes.
  static String shQuote(String value) =>
      "'${value.replaceAll("'", r"'\''")}'";
}
