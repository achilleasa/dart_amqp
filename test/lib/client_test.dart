library dart_amqp.test.client;

import "dart:async";

import "../packages/unittest/unittest.dart";

import "../../lib/src/client.dart";
import "../../lib/src/protocol.dart";
import "../../lib/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

main({bool enableLogger : true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Client test:", () {
    Client client;

    tearDown(() {
      return client.close();
    });

    test("fail to connect after 2 attempts", () {
      ConnectionSettings settings = new ConnectionSettings(
          port : 8765,
          maxConnectionAttempts : 2,
          reconnectWaitTime : const Duration(milliseconds : 10)
      );
      client = new Client(settings : settings);

      client
      .open()
      .catchError(expectAsync((ex) {
        expect(ex, new isInstanceOf<ConnectionFailedException>());
        expect(ex.toString(), startsWith('ConnectionFailedException'));
      }));

    });

    test("multiple open attampts should return the same future", () {
      client = new Client();

      Future connectFuture = client.open();

      expect(client.open(), equals(connectFuture));

      return connectFuture;
    });

    test("multiple close attampts should return the same future", () {
      client = new Client();

      return client.open()
      .then((_) {
        Future closeFuture = client.close();

        expect(client.close(), equals(closeFuture));

        return closeFuture;
      });
    });

    test("exception when exceeding negotiated channel limit", () {

      ConnectionSettings settings = new ConnectionSettings(
          tuningSettings : new TuningSettings()
            ..maxChannels = 1
      );
      client = new Client(settings : settings);

      return client
      .channel()
      .then((_) => client.channel())
      .catchError((ex) {
        expect(ex, new isInstanceOf<StateError>());
        expect(ex.message, equals("Cannot allocate channel; channel limit exceeded (max 1)"));
      });
    });

  });
}