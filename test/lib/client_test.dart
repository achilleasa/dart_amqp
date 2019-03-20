library dart_amqp.test.client;

import "dart:async";

import "package:test/test.dart";

import "package:dart_amqp/src/client.dart";
import "package:dart_amqp/src/protocol.dart";
import "package:dart_amqp/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

main({bool enableLogger = true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Client test:", () {
    Client client;

    tearDown(() {
      return client.close();
    });

    test("fail to connect after 2 attempts", () {
      ConnectionSettings settings = ConnectionSettings(
          port: 8765,
          maxConnectionAttempts: 2,
          reconnectWaitTime: const Duration(milliseconds: 10));
      client = Client(settings: settings);

      client.connect().catchError(expectAsync1((ex) {
        expect(ex, const TypeMatcher<ConnectionFailedException>());
        expect(ex.toString(), startsWith('ConnectionFailedException'));
      }));
    });

    test("multiple open attampts should return the same future", () {
      client = Client();

      Future connectFuture = client.connect();

      expect(client.connect(), equals(connectFuture));

      return connectFuture;
    });

    test("multiple close attampts should return the same future", () {
      client = Client();

      return client.connect().then((_) {
        Future closeFuture = client.close();

        expect(client.close(), equals(closeFuture));

        return closeFuture;
      });
    });

    test("exception when exceeding negotiated channel limit", () {
      ConnectionSettings settings =
          ConnectionSettings(tuningSettings: TuningSettings()..maxChannels = 1);
      client = Client(settings: settings);

      return client.channel().then((_) => client.channel()).catchError((ex) {
        expect(ex, const TypeMatcher<StateError>());
        expect(ex.message,
            equals("Cannot allocate channel; channel limit exceeded (max 1)"));
      });
    });
  });
}
