library dart_amqp.test.auth;

import "package:test/test.dart";
import "package:mockito/mockito.dart";

import "package:dart_amqp/src/authentication.dart";
import "package:dart_amqp/src/client.dart";
import "package:dart_amqp/src/protocol.dart";
import "package:dart_amqp/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

class ConnectionStartMock extends Mock implements ConnectionStart {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 10;

  // Message arguments
  @override
  int versionMajor;
  @override
  int versionMinor;
  @override
  Map<String, Object> serverProperties;
  @override
  String mechanisms;
  @override
  String locales;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeUInt8(versionMajor)
      ..writeUInt8(versionMinor)
      ..writeFieldTable(serverProperties)
      ..writeLongString(mechanisms)
      ..writeLongString(locales);
  }
}

class ConnectionSecureMock extends Mock implements ConnectionSecure {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 20;

  // Message arguments
  @override
  String challenge;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeLongString(challenge);
  }
}

class ConnectionTuneMock extends Mock implements ConnectionTune {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 30;

  // Message arguments
  @override
  int channelMax;
  @override
  int frameMax;
  @override
  int heartbeat;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeUInt16(channelMax)
      ..writeUInt32(frameMax)
      ..writeUInt16(heartbeat);
  }
}

class ConnectionOpenOkMock extends Mock implements ConnectionOpenOk {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 41;
  @override
  String reserved_1;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeShortString(reserved_1);
  }
}

class ConnectionCloseOkMock extends Mock implements ConnectionCloseOk {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 51;

  @override
  void serialize(TypeEncoder encoder) {
    encoder..writeUInt16(msgClassId)..writeUInt16(msgMethodId);
  }
}

class FooAuthProvider implements Authenticator {
  @override
  String get saslType => "foo";

  @override
  String answerChallenge(String challenge) {
    return null;
  }
}

void generateHandshakeMessages(
    FrameWriter frameWriter, mock.MockServer server, int numChapRounds) {
  // Connection start
  frameWriter.writeMessage(
      0,
      ConnectionStartMock()
        ..versionMajor = 0
        ..versionMinor = 9
        ..serverProperties = {"product": "foo"}
        ..mechanisms = "PLAIN"
        ..locales = "en");
  server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
  frameWriter.outputEncoder.writer.clear();

  // Challenge - response rounds
  for (int round = 0; round < numChapRounds; round++) {
    // Connection secure
    frameWriter.writeMessage(
        0, ConnectionSecureMock()..challenge = "round$round");
    server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
    frameWriter.outputEncoder.writer.clear();
  }

  // Connection tune
  frameWriter.writeMessage(
      0,
      ConnectionTuneMock()
        ..channelMax = 0
        ..frameMax = (TuningSettings()).maxFrameSize
        ..heartbeat = 0);
  server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
  frameWriter.outputEncoder.writer.clear();

  // Connection open ok
  frameWriter.writeMessage(0, ConnectionOpenOkMock());
  server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
  frameWriter.outputEncoder.writer.clear();
}

main({bool enableLogger = true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Built-in authentication providers with real server:", () {
    Client client;

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
    Client client;
    mock.MockServer server;
    FrameWriter frameWriter;
    TuningSettings tuningSettings;

    setUp(() {
      tuningSettings = TuningSettings();
      frameWriter = FrameWriter(tuningSettings);
      server = mock.MockServer();
      client = Client(settings: ConnectionSettings(port: 9000));
      return server.listen('127.0.0.1', 9000);
    });

    tearDown(() async {
      await client.close();
      await server.shutdown();
    });

    test("multiple challenge-response rounds", () async {
      generateHandshakeMessages(frameWriter, server, 10);

      // Encode final connection close
      frameWriter.writeMessage(0, ConnectionCloseOkMock());
      server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
      frameWriter.outputEncoder.writer.clear();

      await client.connect();
    });
  });

  group("Exception handling:", () {
    Client client;

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
            e.message,
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
        expect(e.message, equals("Authentication failed"));
      }
    });
  });
}
