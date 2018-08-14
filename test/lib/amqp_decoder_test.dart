library dart_amqp.test.decoder;

import "dart:async";
import "dart:typed_data";

import "package:test/test.dart";
import "package:mockito/mockito.dart";

import "package:dart_amqp/src/enums.dart";
import "package:dart_amqp/src/protocol.dart";
import "package:dart_amqp/src/exceptions.dart";

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

class BasicDeliverMock extends Mock implements BasicDeliver {
  final bool msgHasContent = true;
  final int msgClassId = 60;
  final int msgMethodId = 60;

  // Message arguments
  String consumerTag;
  int deliveryTag;
  bool redelivered;
  String exchange;
  String routingKey;

  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(msgClassId)
      ..writeUInt16(msgMethodId)
      ..writeShortString(consumerTag)
      ..writeUInt64(deliveryTag)
      ..writeUInt8(0)
      ..writeShortString(exchange)
      ..writeShortString(routingKey)
    ;
  }
}


void generateHandshakeMessages(FrameWriter frameWriter, mock.MockServer server) {
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

  group("AMQP decoder:", () {
    StreamController<RawFrame> controller;
    Stream<DecodedMessage> rawStream;
    RawFrame rawFrame;
    FrameWriter frameWriter;
    TuningSettings tuningSettings;

    setUp(() {
      tuningSettings = new TuningSettings();
      frameWriter = new FrameWriter(tuningSettings);

      controller = new StreamController();
      rawStream = controller
      .stream
      .transform(new AmqpMessageDecoder().transformer);
    });

    test("HEADER frame with empty payload size should emit message without waiting for BODY frames", () {
      rawStream
      .listen(expectAsync1((data) {
        expect(data.payload, isNull);
      }));

      new BasicDeliverMock()
        ..routingKey = ""
        ..exchange = ""
        ..deliveryTag = 0
        ..redelivered = false
        ..serialize(frameWriter.outputEncoder);

      FrameHeader header = new FrameHeader();
      header.channel = 1;
      header.type = FrameType.METHOD;
      header.size = frameWriter.outputEncoder.writer.lengthInBytes;

      Uint8List serializedData = frameWriter.outputEncoder.writer.joinChunks();
      frameWriter.outputEncoder.writer.clear();
      rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));
      controller.add(rawFrame);

      // Header frame with 0 payload data
      new ContentHeader()
        ..bodySize = 0
        ..classId = 60
        ..serialize(frameWriter.outputEncoder);

      header = new FrameHeader();
      header.channel = 1;
      header.type = FrameType.HEADER;
      header.size = frameWriter.outputEncoder.writer.lengthInBytes;;

      serializedData = frameWriter.outputEncoder.writer.joinChunks();
      frameWriter.outputEncoder.writer.clear();
      rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));

      controller.add(rawFrame);
    });

    group("exception handling", () {
      test("METHOD frame while still processing previous METHOD frame", () {

        rawStream
        .listen((data) {
          fail("Expected exception to be thrown");
        },
        onError : expectAsync1((error) {
          expect(error, const TypeMatcher<ConnectionException>());
          expect(error.toString(), equals("ConnectionException(UNEXPECTED_FRAME): Received a new METHOD frame while processing an incomplete METHOD frame"));
        }));

        new BasicDeliverMock()
          ..routingKey = ""
          ..exchange = ""
          ..deliveryTag = 0
          ..redelivered = false
          ..serialize(frameWriter.outputEncoder);

        FrameHeader header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.METHOD;
        header.size = frameWriter.outputEncoder.writer.lengthInBytes;

        Uint8List serializedData = frameWriter.outputEncoder.writer.joinChunks();
        frameWriter.outputEncoder.writer.clear();
        rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));

        // The second method frame should trigger the exception
        controller.add(rawFrame);
        controller.add(rawFrame);
      });

      test("HEADER frame without a previous METHOD frame", () {

        rawStream
        .listen((data) {
          fail("Expected exception to be thrown");
        },
        onError : expectAsync1((error) {
          expect(error, const TypeMatcher<ConnectionException>());
          expect(error.toString(), equals("ConnectionException(UNEXPECTED_FRAME): Received a HEADER frame without a matching METHOD frame"));
        }));

        new ContentHeader()
          ..bodySize = 0
          ..classId = 1
          ..serialize(frameWriter.outputEncoder);

        FrameHeader header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.HEADER;
        header.size = frameWriter.outputEncoder.writer.lengthInBytes;

        Uint8List serializedData = frameWriter.outputEncoder.writer.joinChunks();
        frameWriter.outputEncoder.writer.clear();
        rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));

        controller.add(rawFrame);
      });

      test("HEADER frame not matching previous METHOD frame class", () {

        rawStream
        .listen((data) {
          fail("Expected exception to be thrown");
        },
        onError : expectAsync1((error) {
          expect(error, const TypeMatcher<ConnectionException>());
          expect(error.toString(), equals("ConnectionException(UNEXPECTED_FRAME): Received a HEADER frame that does not match the METHOD frame class id"));
        }));

        new BasicDeliverMock()
          ..routingKey = ""
          ..exchange = ""
          ..deliveryTag = 0
          ..redelivered = false
          ..serialize(frameWriter.outputEncoder);

        FrameHeader header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.METHOD;
        header.size = frameWriter.outputEncoder.writer.lengthInBytes;

        Uint8List serializedData = frameWriter.outputEncoder.writer.joinChunks();
        frameWriter.outputEncoder.writer.clear();
        rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));
        controller.add(rawFrame);

        // Write content header with different class id
        new ContentHeader()
          ..bodySize = 0
          ..classId = 0
          ..serialize(frameWriter.outputEncoder);

        header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.HEADER;
        header.size = frameWriter.outputEncoder.writer.lengthInBytes;

        serializedData = frameWriter.outputEncoder.writer.joinChunks();
        frameWriter.outputEncoder.writer.clear();
        rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));

        controller.add(rawFrame);
      });

      test("duplicate HEADER frame for incomplete METHOD frame", () {

        rawStream
        .listen((data) {
          fail("Expected exception to be thrown");
        },
        onError : expectAsync1((error) {
          expect(error, const TypeMatcher<ConnectionException>());
          expect(error.toString(), equals("ConnectionException(UNEXPECTED_FRAME): Received a duplicate HEADER frame for an incomplete METHOD frame"));
        }));

        new BasicDeliverMock()
          ..routingKey = ""
          ..exchange = ""
          ..deliveryTag = 0
          ..redelivered = false
          ..serialize(frameWriter.outputEncoder);

        FrameHeader header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.METHOD;
        header.size = frameWriter.outputEncoder.writer.lengthInBytes;

        Uint8List serializedData = frameWriter.outputEncoder.writer.joinChunks();
        frameWriter.outputEncoder.writer.clear();
        rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));
        controller.add(rawFrame);

        // Write content header with different class id
        new ContentHeader()
          ..bodySize = 1
          ..classId = 60
          ..serialize(frameWriter.outputEncoder);

        header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.HEADER;
        header.size = frameWriter.outputEncoder.writer.lengthInBytes;

        serializedData = frameWriter.outputEncoder.writer.joinChunks();
        frameWriter.outputEncoder.writer.clear();
        rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));

        // The second addition should trigger the error
        controller.add(rawFrame);
        controller.add(rawFrame);
      });

      test("BODY frame without matching METHOD frame", () {

        rawStream
        .listen((data) {
          fail("Expected exception to be thrown");
        },
        onError : expectAsync1((error) {
          expect(error, const TypeMatcher<ConnectionException>());
          expect(error.toString(), equals("ConnectionException(UNEXPECTED_FRAME): Received a BODY frame without a matching METHOD frame"));
        }));

        FrameHeader header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.BODY;
        header.size = 0;

        rawFrame = new RawFrame(header, null);
        controller.add(rawFrame);
      });

      test("BODY frame without HEADER frame", () {

        rawStream
        .listen((data) {
          fail("Expected exception to be thrown");
        },
        onError : expectAsync1((error) {
          expect(error, const TypeMatcher<ConnectionException>());
          expect(error.toString(), equals("ConnectionException(UNEXPECTED_FRAME): Received a BODY frame before a HEADER frame"));
        }));

        new BasicDeliverMock()
          ..routingKey = ""
          ..exchange = ""
          ..deliveryTag = 0
          ..redelivered = false
          ..serialize(frameWriter.outputEncoder);

        FrameHeader header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.METHOD;
        header.size = frameWriter.outputEncoder.writer.lengthInBytes;

        Uint8List serializedData = frameWriter.outputEncoder.writer.joinChunks();
        frameWriter.outputEncoder.writer.clear();
        rawFrame = new RawFrame(header, new ByteData.view(serializedData.buffer, 0, serializedData.lengthInBytes));
        controller.add(rawFrame);

        // Write body
        header = new FrameHeader();
        header.channel = 1;
        header.type = FrameType.BODY;
        header.size = 0;

        rawFrame = new RawFrame(header, null);
        controller.add(rawFrame);
      });
    });
  });
}
