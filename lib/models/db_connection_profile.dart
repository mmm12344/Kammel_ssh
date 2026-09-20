import 'dart:convert';

class DbConnectionProfile {
  final String id;
  final String sshProfileId;
  final String name;
  final String engine; // 'postgres' | 'mysql'
  final String host;
  final int port;
  final String username;
  final String password;
  final String databaseName;
  final String? dockerContainer; // Opcional, si corre dentro de Docker

  DbConnectionProfile({
    required this.id,
    required this.sshProfileId,
    required this.name,
    required this.engine,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.databaseName,
    this.dockerContainer,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sshProfileId': sshProfileId,
        'name': name,
        'engine': engine,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'databaseName': databaseName,
        'dockerContainer': dockerContainer,
      };

  factory DbConnectionProfile.fromMap(Map<String, dynamic> map) =>
      DbConnectionProfile(
        id: map['id'] ?? '',
        sshProfileId: map['sshProfileId'] ?? '',
        name: map['name'] ?? '',
        engine: map['engine'] ?? 'postgres',
        host: map['host'] ?? 'localhost',
        port: map['port'] ?? (map['engine'] == 'mysql' ? 3306 : 5432),
        username: map['username'] ?? '',
        password: map['password'] ?? '',
        databaseName: map['databaseName'] ?? '',
        dockerContainer: map['dockerContainer'],
      );

  /// The password is the one field prefs never hold, so a load resolves it
  /// from secure storage and reattaches it here (null keeps the existing).
  DbConnectionProfile copyWith({String? password}) => DbConnectionProfile(
        id: id,
        sshProfileId: sshProfileId,
        name: name,
        engine: engine,
        host: host,
        port: port,
        username: username,
        password: password ?? this.password,
        databaseName: databaseName,
        dockerContainer: dockerContainer,
      );

  String toJson() => json.encode(toMap());

  /// Same as [toMap] but without the secret ([password]). This is the shape
  /// that belongs in plain shared_preferences and in backups — the password
  /// itself lives in secure storage under `dbpw_<id>` (see [SecureStore]).
  Map<String, dynamic> toMapPublic() {
    final map = toMap();
    map.remove('password');
    return map;
  }

  String toJsonPublic() => json.encode(toMapPublic());

  factory DbConnectionProfile.fromJson(String source) =>
      DbConnectionProfile.fromMap(json.decode(source));
}
