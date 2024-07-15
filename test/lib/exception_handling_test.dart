library dart_amqp.test.exceptions;

import "dart:typed_data";
import "dart:async";
import "dart:math";

import "package:test/test.dart";
import "package:mockito/mockito.dart";

import "package:dart_amqp/src/client.dart";
import "package:dart_amqp/src/enums.dart";
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
  int versionMajor = 0;
  @override
  int versionMinor = 0;
  @override
  Map<String, Object?>? serverProperties;
  @override
  String mechanisms = "";
  @override
  String locales = "";

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

class ConnectionTuneMock extends Mock implements ConnectionTune {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 10;
  @override
  final int msgMethodId = 30;

  // Message arguments
  @override
  int channelMax = 0;
  @override
  int frameMax = 0;
  @override
  int heartbeat = 0;

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
  String? reserved_1;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeShortString(reserved_1);
  }
}

class TxSelectOkMock extends Mock implements TxSelectOk {
  @override
  final bool msgHasContent = false;
  @override
  final int msgClassId = 90;
  @override
  final int msgMethodId = 11;

  @override
  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId);
  }
}

void generateHandshakeMessages(
    FrameWriter frameWriter, mock.MockServer server) {
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
  Random rnd = Random();
  if (enableLogger) {
    mock.initLogger();
  }

  group("Exception handling:", () {
    late Client client;
    late mock.MockServer server;
    late FrameWriter frameWriter;
    late TuningSettings tuningSettings;
    late int port;

    setUp(() {
      tuningSettings = TuningSettings();
      frameWriter = FrameWriter(tuningSettings);
      server = mock.MockServer();
      port = 9000 + rnd.nextInt(100);
      client = Client(settings: ConnectionSettings(port: port));
      return server.listen('127.0.0.1', port);
    });

    tearDown(() async {
      await client.close();
      await server.shutdown();
    });

    group("fatal exceptions:", () {
      test("protocol mismatch", () async {
        TypeEncoder encoder = TypeEncoder();
        ProtocolHeader()
          ..protocolVersion = 0
          ..majorVersion = 0
          ..minorVersion = 8
          ..revision = 0
          ..serialize(encoder);

        server.replayList.add(encoder.writer.joinChunks());

        void handleError(ex, s) {
          expect(ex, const TypeMatcher<FatalException>());
          expect(
              ex.message,
              equalsIgnoringCase(
                  "Could not negotiate a valid AMQP protocol version. Server supports AMQP 0.8.0"));
        }

        try {
          await client.connect();
          fail("Expected a FatalException to be thrown");
        } catch (e, s) {
          handleError(e, s);
        }
      });

      test("frame without terminator", () async {
        frameWriter.writeMessage(
            0,
            ConnectionStartMock()
              ..versionMajor = 0
              ..versionMinor = 9
              ..serverProperties = {"product": "foo"}
              ..mechanisms = "PLAIN"
              ..locales = "en");
        Uint8List frameData = frameWriter.outputEncoder.writer.joinChunks();
        // Set an invalid frame terminator to the mock server response
        frameData[frameData.length - 1] = 0xF0;
        server.replayList.add(frameData);

        void handleError(ex, s) {
          expect(ex, const TypeMatcher<FatalException>());
          expect(
              ex.message,
              equalsIgnoringCase(
                  "Frame did not end with the expected frame terminator (0xCE)"));
        }

        try {
          await client.connect();
          fail("Expected an exception to be thrown");
        } catch (e, s) {
          handleError(e, s);
        }
      });

      test("frame on channel > 0 while handshake in progress", () async {
        frameWriter.writeMessage(
            1,
            ConnectionStartMock()
              ..versionMajor = 0
              ..versionMinor = 9
              ..serverProperties = {"product": "foo"}
              ..mechanisms = "PLAIN"
              ..locales = "en");
        server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());

        void handleError(ex, s) {
          expect(ex, const TypeMatcher<FatalException>());
          expect(
              ex.message,
              equalsIgnoringCase(
                  "Received message for channel 1 while still handshaking"));
        }

        try {
          await client.connect();
          fail("Expected an exception to be thrown");
        } catch (e, s) {
          handleError(e, s);
        }
      });

      test("unexpected frame during handshake", () async {
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

        // Connection tune
        frameWriter.writeMessage(
            0,
            ConnectionTuneMock()
              ..channelMax = 0
              ..frameMax = (TuningSettings()).maxFrameSize
              ..heartbeat = 0);
        server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
        frameWriter.outputEncoder.writer.clear();

        // Unexpected frame
        frameWriter.writeMessage(0, TxSelectOkMock());
        server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());
        frameWriter.outputEncoder.writer.clear();

        void handleError(ex, s) {
          expect(ex, const TypeMatcher<FatalException>());
          expect(
              ex.message,
              equalsIgnoringCase(
                  "Received unexpected message TxSelectOk during handshake"));
        }

        try {
          await client.connect();
          fail("Expected an exception to be thrown");
        } catch (e, s) {
          handleError(e, s);
        }
      });
    });

    group("connection exceptions:", () {
      test("illegal frame size", () async {
        frameWriter.writeMessage(
            0,
            ConnectionStartMock()
              ..versionMajor = 0
              ..versionMinor = 9
              ..serverProperties = {"product": "foo"}
              ..mechanisms = "PLAIN"
              ..locales = "en");
        Uint8List frameData = frameWriter.outputEncoder.writer.joinChunks();
        // Manipulate the frame header to indicate a too long message
        int len = tuningSettings.maxFrameSize + 1;
        frameData[3] = (len >> 24) & 0xFF;
        frameData[4] = (len >> 16) & 0xFF;
        frameData[5] = (len >> 8) & 0xFF;
        frameData[6] = (len) & 0xFF;
        server.replayList.add(frameData);

        void handleError(ex, s) {
          expect(ex, const TypeMatcher<ConnectionException>());
          expect(
              ex.message,
              equalsIgnoringCase(
                  "Frame size cannot be larger than ${tuningSettings.maxFrameSize} bytes. Server sent ${tuningSettings.maxFrameSize + 1} bytes"));
        }

        try {
          await client.connect();
          fail("Expected an exception to be thrown");
        } catch (e, s) {
          handleError(e, s);
        }
      });

      test("connection-class message on channel > 0 post handshake", () async {
        generateHandshakeMessages(frameWriter, server);

        // Add a fake connection start message at channel 1
        frameWriter.writeMessage(
            1,
            ConnectionStartMock()
              ..versionMajor = 0
              ..versionMinor = 9
              ..serverProperties = {"product": "foo"}
              ..mechanisms = "PLAIN"
              ..locales = "en");
        server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());

        void handleError(ex, s) {
          expect(ex, const TypeMatcher<ConnectionException>());
          expect(
              ex.message,
              equalsIgnoringCase(
                  "Received CONNECTION class message on a channel > 0"));
        }

        try {
          await client.channel();
          fail("Expected an exception to be thrown");
        } catch (e, s) {
          handleError(e, s);
        }
      });

      test("HEARTBEAT message on channel > 0", () async {
        generateHandshakeMessages(frameWriter, server);

        // Add a heartbeat start message at channel 1
        frameWriter.outputEncoder.writer.addLast(Uint8List.fromList(
            [8, 0, 1, 0, 0, 0, 0, RawFrameParser.FRAME_TERMINATOR]));
        server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());

        void handleError(ex, s) {
          expect(ex, const TypeMatcher<ConnectionException>());
          expect(
              ex.message,
              equalsIgnoringCase(
                  "Received HEARTBEAT message on a channel > 0"));
        }

        try {
          await client.channel();
          fail("Expected an exception to be thrown");
        } catch (e, s) {
          handleError(e, s);
        }
      });

      test("connection close message post handshake", () async {
        generateHandshakeMessages(frameWriter, server);

        // Add a fake connection start message at channel 1
        frameWriter.writeMessage(
            0,
            ConnectionClose()
              ..classId = 10
              ..methodId = 40
              ..replyCode = ErrorType.ACCESS_REFUSED.value
              ..replyText = "No access");
        server.replayList.add(frameWriter.outputEncoder.writer.joinChunks());

        void handleError(ex, s) {
          expect(ex, const TypeMatcher<ConnectionException>());
          expect(ex.toString(),
              equals("ConnectionException(ACCESS_REFUSED): No access"));
        }

        try {
          await client.channel();
          fail("Expected an exception to be thrown");
        } catch (e, s) {
          handleError(e, s);
        }
      });
    });
    group("error stream:", () {
      test("fatal exception", () async {
        void handleError(ex) {
          expect(ex, const TypeMatcher<FatalException>());
        }

        // ignore: unawaited_futures
        server.shutdown().then((_) async {
          await server.listen(client.settings.host!, client.settings.port!);
          generateHandshakeMessages(frameWriter, server);
          await client.connect();
          client.errorListener((ex) => handleError(ex));
          await server.shutdown();
          await Future.delayed(
              const Duration(seconds: 5) + server.responseDelay);
          fail("Expected an exception to be thrown");
        });
      });
    }, skip: true);
  });
}
