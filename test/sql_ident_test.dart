import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_agent/services/server_controller.dart';

void main() {
  group('sqlIdent', () {
    test('quotes for each engine', () {
      expect(sqlIdent('users', postgres: true), '"users"');
      expect(sqlIdent('users', postgres: false), '`users`');
    });

    test('accepts the shapes real databases produce', () {
      for (final name in ['users', '_meta', 'user_accounts', 'col1', 'a_\$b']) {
        expect(sqlIdent(name, postgres: true), '"$name"', reason: name);
      }
    });

    test('refuses anything that is not a plain identifier', () {
      // Second-order injection: a hostile *table name* on a shared server
      // must be refused, not escaped into a query the app then runs.
      const hostile = [
        'x"; DROP TABLE users; --',
        'x`; DROP TABLE users; --',
        "it's",
        'a b',
        'a-b',
        'a.b',
        'a;b',
        '',
        '1col',
        "'",
        '"',
        '`',
      ];
      for (final name in hostile) {
        expect(() => sqlIdent(name, postgres: true),
            throwsFormatException,
            reason: name);
        expect(() => sqlIdent(name, postgres: false),
            throwsFormatException,
            reason: name);
      }
    });
  });

  group('sqlString', () {
    test('doubles embedded quotes', () {
      expect(sqlString("it's"), "'it''s'");
      expect(sqlString('plain'), "'plain'");
    });

    test('an escaped value cannot terminate the literal early', () {
      final v = sqlString("x'; DROP TABLE users; --");
      expect(v, r"'x''; DROP TABLE users; --'");
      // The literal still ends exactly one quote later than the payload.
      expect(v.lastIndexOf("'"), v.length - 1);
    });
  });
}
