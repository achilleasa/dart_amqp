library dart_amqp.test.auth;

import "../packages/unittest/unittest.dart";
import "../packages/mock/mock.dart";

import "../../lib/src/authentication.dart";
import "../../lib/src/client.dart";
import "../../lib/src/protocol.dart";
import "../../lib/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

class ConnectionStartMock extends Mock implements ConnectionStart {
  final bool msgHasContent = false;
  final int msgClassId = 10;
  final int msgMethodId = 10;

  // Message arguments
  int versionMajor;
  int versionMinor;
  Map<String, Object> serverProperties;
  String mechanisms;
  String locales;

  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeUInt8(versionMajor)
      ..writeUInt8(versionMinor)
      ..writeFieldTable(serverProperties)
      ..writeLongString(mechanisms)
      ..writeLongString(locales)
    ;
  }
}

class ConnectionSecureMock extends Mock implements ConnectionSecure {
  final bool msgHasContent = false;
  final int msgClassId = 10;
  final int msgMethodId = 20;

  // Message arguments
  String challenge;

  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeLongString(challenge)
    ;
  }
}

class ConnectionTuneMock extends Mock implements ConnectionTune {
  final bool msgHasContent = false;
  final int msgClassId = 10;
  final int msgMethodId = 30;

  // Message arguments
  int channelMax;
  int frameMax;
  int heartbeat;

  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeUInt16(channelMax)
      ..writeUInt32(frameMax)
      ..writeUInt16(heartbeat)
    ;
  }
}

class ConnectionOpenOkMock extends Mock implements ConnectionOpenOk {
  final bool msgHasContent = false;
  final int msgClassId = 10;
  final int msgMethodId = 41;
  String reserved_1;

  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeShortString(reserved_1)
    ;
  }
}

class ConnectionCloseOkMock extends Mock implements ConnectionCloseOk {
  final bool msgHasContent = false;
  final int msgClassId = 10;
  final int msgMethodId = 51;

  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
    ;
  }
}

class FooAuthProvider implements Authenticator {
  String get saslType => "foo";

  String answerChallenge(String challenge) {
    return null;
  }

}

void generateHandshakeMessages(FrameWriter frameWriter, mock.MockServer server, int numChapRounds) {
  // Connection start
  frameWriter.writeMessage(0, new ConnectionStartMock()
    ..versionMajor = 0
    ..versionMinor = 9
    ..serverProperties = {
      "product" : "foo"
  }
    ..mechanisms = "PLAIN"
    ..locales = "en");
  server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
  frameWriter.outputEncoder.writer.clear();

  // Challenge - response rounds
  for (int round = 0; round < numChapRounds; round++) {
    // Connection secure
    frameWriter.writeMessage(
        0,
        new ConnectionSecureMock()
          ..challenge = "round${round}"
        );
    server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
    frameWriter.outputEncoder.writer.clear();
  }

  // Connection tune
  frameWriter.writeMessage(0, new ConnectionTuneMock()
    ..channelMax = 0
    ..frameMax = (new TuningSettings()).maxFrameSize
    ..heartbeat = 0);
  server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
  frameWriter.outputEncoder.writer.clear();

  // Connection open ok
  frameWriter.writeMessage(0, new ConnectionOpenOkMock());
  server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
  frameWriter.outputEncoder.writer.clear();
}

main({bool enableLogger : true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Built-in authentication providers with real server:", () {
    Client client;

    tearDown(() {
      return client.close();
    });

    test("PLAIN authenticaion", () {
      ConnectionSettings settings = new ConnectionSettings(
          authProvider : new PlainAuthenticator("guest", "guest")
          );
      client = new Client(settings : settings);

      client
      .connect()
      .then(expectAsync((_) {
      }));
    });

    test("AMQPLAIN authenticaion", () {
      ConnectionSettings settings = new ConnectionSettings(
          authProvider : new AmqPlainAuthenticator("guest", "guest")
          );
      client = new Client(settings : settings);

      client
      .connect()
      .then(expectAsync((_) {
      }));
    });
  });

  group("Challenge-response:", () {
    Client client;
    mock.MockServer server;
    FrameWriter frameWriter;
    TuningSettings tuningSettings;

    setUp(() {
      tuningSettings = new TuningSettings();
      frameWriter = new FrameWriter(tuningSettings);
      server = new mock.MockServer();
      client = new Client(settings : new ConnectionSettings(port : 9000));
      return server.listen('127.0.0.1', 9000);
    });

    tearDown(() {
      return client.close()
        .then( (_) => server.shutdown() );
    });

    test("multiple challenge-response rounds", () {
      generateHandshakeMessages(frameWriter, server, 10);

      // Encode final connection close
      frameWriter.writeMessage(0, new ConnectionCloseOkMock());
      server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
      frameWriter.outputEncoder.writer.clear();

      client
      .connect()
      .then(expectAsync((_) {
      }));
    });
  });

  group("Exception handling:", () {
    Client client;

    tearDown(() {
      return client.close();
    });

    test("unsupported SASL provider", () {
      ConnectionSettings settings = new ConnectionSettings(authProvider : new FooAuthProvider());

      client = new Client(settings : settings);

      client
      .connect()
      .catchError(expectAsync((e) {
        expect(e, new isInstanceOf<FatalException>());
        expect(e.message, startsWith("Selected authentication provider 'foo' is unsupported by the server"));
      }));
    });

    test("invalid auth credentials", () {
      ConnectionSettings settings = new ConnectionSettings(authProvider : new PlainAuthenticator("foo", "foo"));

      client = new Client(settings : settings);

      client
      .connect()
      .catchError(expectAsync((e) {
        expect(e, new isInstanceOf<FatalException>());
        expect(e.message, equals("Authentication failed"));
      }));
    });
  });
}