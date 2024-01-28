library dart_amqp.test.auth;

import "package:test/test.dart";

import "package:dart_amqp/src/authentication.dart";
import "package:dart_amqp/src/client.dart";
import "package:dart_amqp/src/protocol.dart";
import "package:dart_amqp/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

class FooAuthProvider implements Authenticator {
  @override
  String get saslType => "foo";

  @override
  String answerChallenge(String? challenge) {
    return "";
  }
}

main({bool enableLogger = true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Built-in authentication providers with real server:", () {
    late Client client;

    tearDown(() {
      return client.close();
    });

    test("PLAIN authenticaion", () async {
      ConnectionSettings settings = ConnectionSettings(
          authProvider: const PlainAuthenticator("guest", "guest"));
      client = Client(settings: settings);

      await client.connect();
    });

    test("AMQPLAIN authenticaion", () async {
      ConnectionSettings settings = ConnectionSettings(
          authProvider: const AmqPlainAuthenticator("guest", "guest"));
      client = Client(settings: settings);

      await client.connect();
    });
  });

  group("Challenge-response:", () {
    late Client client;
    late mock.MockServer server;
    late FrameWriter frameWriter;
    TuningSettings tuningSettings;

    setUp(() {
      tuningSettings = TuningSettings();
      frameWriter = FrameWriter(tuningSettings);
      server = mock.MockServer();
      client = Client(settings: ConnectionSettings(port: 9001));
      return server.listen('127.0.0.1', 9001);
    });

    tearDown(() async {
      await client.close();
      await server.shutdown();
    });

    test("multiple challenge-response rounds", () async {
      server.generateHandshakeMessages(frameWriter, numChapRounds: 10);

      // Encode final connection close
      frameWriter.writeMessage(0, mock.ConnectionCloseOkMock());
      server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
      frameWriter.outputEncoder.writer.clear();

      await client.connect();
    });
  });

  group("Exception handling:", () {
    late Client client;

    tearDown(() {
      return client.close();
    });

    test("unsupported SASL provider", () async {
      ConnectionSettings settings =
          ConnectionSettings(authProvider: FooAuthProvider());

      client = Client(settings: settings);

      try {
        await client.connect();
      } catch (e) {
        expect(e, const TypeMatcher<FatalException>());
        expect(
            (e as FatalException).message,
            startsWith(
                "Selected authentication provider 'foo' is unsupported by the server"));
      }
    });

    test("invalid auth credentials", () async {
      ConnectionSettings settings = ConnectionSettings(
          authProvider: const PlainAuthenticator("foo", "foo"));

      client = Client(settings: settings);

      try {
        await client.connect();
      } catch (e) {
        expect(e, const TypeMatcher<FatalException>());
        expect((e as FatalException).message, equals("Authentication failed"));
      }
    });
  });
}
