library dart_amqp.test.encode_decode;

import "dart:async";
import "dart:typed_data";

import "package:test/test.dart";

import "package:dart_amqp/src/protocol.dart";

import "mocks/mocks.dart" as mock;

TypeDecoder decoderFromEncoder(TypeEncoder encoder) {
  Uint8List data = encoder.writer.joinChunks();
  return TypeDecoder.fromBuffer(
      ByteData.view(data.buffer, 0, data.lengthInBytes));
}

main({bool enableLogger = true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Encode/decode:", () {
    TypeEncoder encoder;
    TypeDecoder decoder;

    setUp(() {
      encoder = TypeEncoder();
    });

    test("uint8", () {
      encoder.writeUInt8(255);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readUInt8(), equals(255));
    });

    test("uint16", () {
      encoder.writeUInt16(65535);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readUInt16(), equals(65535));
    });

    test("uint32", () {
      encoder.writeUInt32(0xFFFFFFFF);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readUInt32(), equals(0xFFFFFFFF));
    });

    test("uint64", () {
      encoder.writeUInt64(0xFFFFFFFFFFFFFFFF);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readUInt64(), equals(0xFFFFFFFFFFFFFFFF));
    });

    test("int8", () {
      encoder.writeInt8(-128);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readInt8(), equals(-0x80));
    });

    test("int16", () {
      encoder.writeInt16(-32768);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readInt16(), equals(-0x8000));
    });

    test("int32", () {
      encoder.writeInt32(-2147483648);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readInt32(), equals(-0x80000000));
    });

    test("int64", () {
      encoder.writeInt64(-21474836480);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readInt64(), equals(-21474836480));
    });

    test("float", () {
      encoder.writeFloat(-3.141);
      decoder = decoderFromEncoder(encoder);

      // Due to float/double representation inconsistencies we need to use a threshold match
      expect((-3.141 - decoder.readFloat()).abs(), lessThan(0.0001));
    });

    test("double", () {
      encoder.writeDouble(3.141142);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readDouble(), equals(3.141142));
    });

    test("bitmap", () {
      encoder.writeBits(
          [false, true, false, true, false, true, false, true, false, true]);
      decoder = decoderFromEncoder(encoder);

      // 0XAA   = 10101010
      // 0x2    = 00000010
      // Expected bitmap value should be:
      // 0zAA02 = 10101010 00000010
      int expectedValue = (0xAA) << 8 | 0x2;

      expect(decoder.readUInt16(), equals(expectedValue));
    });

    test("shortString", () {
      encoder.writeShortString("test 123");
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readShortString(), equals("test 123"));
    });

    test("shortString (null)", () {
      encoder.writeShortString(null);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readShortString(), equals(""));
    });

    test("shortString max length", () {
      String longString =
          String.fromCharCodes(List<int>.generate(256, (int index) => index));

      expect(() => encoder.writeShortString(longString),
          throwsA((e) => e is ArgumentError));
    });

    test("longString", () {
      encoder.writeLongString("test 123");
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readLongString(), equals("test 123"));
    });

    test("longString (null)", () {
      encoder.writeLongString(null);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readLongString(), equals(""));
    });

    test("timestamp", () {
      // Use second accuracy
      DateTime now = DateTime.now();
      now = now.subtract(Duration(
          milliseconds: now.millisecond, microseconds: now.microsecond));

      encoder.writeTimestamp(now);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readTimestamp(), equals(now));
    });

    test("timestamp (null)", () {
      encoder.writeTimestamp(null);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readTimestamp(), equals(null));
    });

    test("array", () {
      Iterable arrayData = ["foo", "bar"];

      encoder.writeArray("data", arrayData);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readArray("data"), equals(arrayData));
    });

    test("table", () {
      // Use second accuracy
      DateTime now = DateTime.now();
      now = now.subtract(Duration(
          milliseconds: now.millisecond, microseconds: now.microsecond));

      final tableData = {
        "map": {
          "list": ["foo", "bar", "baz"]
        },
        "bool": true,
        "unsigned": {
          "uint8": 0xFF,
          "uint16": 0xFFFF,
          "uint32": 0xFFFFFFFF,
          "uint64": 0xFFFFFFFFFFFFFFFF
        },
        "signed": {
          "int8": -0x80,
          "int16": -0x8000,
          "int32": -0x80000000,
          "int64": -0x800000000000000
        },
        "string": "Hello world",
        "float": -3.141,
        "double": 3.14151617,
        "timestamp": now,
        "void": null
      };

      encoder.writeFieldTable(tableData);
      decoder = decoderFromEncoder(encoder);

      expect(decoder.readFieldTable("data"), equals(tableData));
    });

    test("table (unsupported field exception)", () {
      // Use second accuracy
      DateTime now = DateTime.now();
      now = now.subtract(Duration(
          milliseconds: now.millisecond, microseconds: now.microsecond));

      final tableData = {"unsupported": StreamController()};

      expect(
          () => encoder.writeFieldTable(tableData),
          throwsA((ex) =>
              ex is ArgumentError &&
              ex.message.startsWith("Could not encode field unsupported")));
    });
  });
}
