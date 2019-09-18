library dart_amqp.test.client;

import 'dart:async';

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

    tearDown(() async {
      await client.close();
    });

    test("fail to connect after 2 attempts", () async {
      ConnectionSettings settings = ConnectionSettings(
          port: 8765,
          maxConnectionAttempts: 2,
          reconnectWaitTime: const Duration(milliseconds: 10));
      client = Client(settings: settings);

      try {
        await client.connect();
      } catch (ex) {
        expect(ex, const TypeMatcher<ConnectionFailedException>());
        expect(ex.toString(), startsWith('ConnectionFailedException'));
      }
    });

    test("multiple open attampts should return the same future", () async {
      client = Client();
      Future connectFuture = client.connect();
      expect(client.connect(), equals(connectFuture));
      await connectFuture;
    });

    test("multiple close attampts should return the same future", () async {
      client = Client();
      await client.connect();
      Future closeFuture = client.close();
      expect(client.close(), equals(closeFuture));
      await closeFuture;
    });

    test("exception when exceeding negotiated channel limit", () async {
      ConnectionSettings settings =
          ConnectionSettings(tuningSettings: TuningSettings()..maxChannels = 1);
      client = Client(settings: settings);

      await client.channel();
      try {
        await client.channel();
      } catch (ex) {
        expect(ex, const TypeMatcher<StateError>());
        expect(ex.message,
            equals("Cannot allocate channel; channel limit exceeded (max 1)"));
      }
    });
  });
}
