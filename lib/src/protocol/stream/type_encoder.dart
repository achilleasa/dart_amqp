part of "../../protocol.dart";

class TypeEncoder {
  late ChunkedOutputWriter _writer;

  final Endian endianess = Endian.big;

  TypeEncoder({ChunkedOutputWriter? withWriter}) {
    _writer = withWriter ?? ChunkedOutputWriter();
  }

  void writeInt8(int value) {
    Uint8List buf = Uint8List(1);
    ByteData.view(buf.buffer).setInt8(0, value);
    _writer.addLast(buf);
  }

  void writeInt16(int value) {
    Uint8List buf = Uint8List(2);
    ByteData.view(buf.buffer).setInt16(0, value, endianess);
    _writer.addLast(buf);
  }

  void writeInt32(int value) {
    Uint8List buf = Uint8List(4);
    ByteData.view(buf.buffer).setInt32(0, value, endianess);
    _writer.addLast(buf);
  }

  void writeInt64(int value) {
    Uint8List buf = Uint8List(8);
    ByteData.view(buf.buffer).setInt64(0, value, endianess);
    _writer.addLast(buf);
  }

  void writeUInt8(int value) {
    Uint8List buf = Uint8List(1);
    ByteData.view(buf.buffer).setUint8(0, value);
    _writer.addLast(buf);
  }

  void writeUInt16(int value) {
    Uint8List buf = Uint8List(2);
    ByteData.view(buf.buffer).setUint16(0, value, endianess);
    _writer.addLast(buf);
  }

  void writeUInt32(int value) {
    Uint8List buf = Uint8List(4);
    ByteData.view(buf.buffer).setUint32(0, value, endianess);
    _writer.addLast(buf);
  }

  void writeUInt64(int value) {
    const kIsWeb = bool.fromEnvironment('dart.library.js_util');
    if (kIsWeb) {
      _writer.addLast(Uint64Converter.uint64ToUint8List(value));
    } else {
      Uint8List buf = Uint8List(8);
      ByteData.view(buf.buffer).setUint64(0, value, endianess);
      _writer.addLast(buf);
    }
  }

  writeFloat(double value) {
    Uint8List buf = Uint8List(4);
    ByteData.view(buf.buffer).setFloat32(0, value, endianess);
    _writer.addLast(buf);
  }

  writeDouble(double value) {
    Uint8List buf = Uint8List(8);
    ByteData.view(buf.buffer).setFloat64(0, value, endianess);
    _writer.addLast(buf);
  }

  void writeBits(List<bool> bits) {
    int mask = 0;

    for (int maskOffset = 0, index = 0;
        index < bits.length;
        maskOffset++, index++) {
      if (index > 0 && index % 8 == 0) {
        writeUInt8(mask);
        mask = 0;
        maskOffset = 0;
      }

      if (bits[index] == true) {
        mask |= 1 << maskOffset;
      }
    }

    // Emit final mask
    writeUInt8(mask);
  }

  void writeShortString(String? value) {
    if (value == null || value.isEmpty) {
      writeUInt8(0);
      return;
    }

    var data = Uint8List.fromList(utf8.encode(value));

    if (data.length > 255) {
      throw ArgumentError("Short string values should have a length <= 255");
    }

    // Write the length followed by the actual bytes
    writeUInt8(data.length);
    _writer.addLast(data);
  }

  void writeLongString(String? value) {
    if (value == null || value.isEmpty) {
      writeUInt32(0);
      return;
    }

    var data = Uint8List.fromList(utf8.encode(value));

    // Write the length followed by the actual bytes
    writeUInt32(data.length);
    _writer.addLast(data);
  }

  void writeTimestamp(DateTime? value) {
    if (value == null) {
      writeUInt64(0);
      return;
    }

    // rabbit uses 64-bit POSIX time_t format (1 sec accuracy)
    writeUInt64(value.millisecondsSinceEpoch ~/ 1000);
  }

  void writeFieldTable(Map<String, Object?>? table) {
    if (table == null || table.isEmpty) {
      writeInt32(0);
      return;
    }

    TypeEncoder buffer = TypeEncoder();

    // Encode each keypair to the buffer
    table.forEach((String fieldName, Object? value) {
      buffer.writeShortString(fieldName);
      buffer._writeField(fieldName, value);
    });

    // Now that the length in bytes is known append it to output
    // followed by the buffered data
    writeInt32(buffer.writer.lengthInBytes);
    writer.addLast(buffer.writer.joinChunks());
  }

  void writeArray(String fieldName, Iterable? value) {
    if (value == null || value.isEmpty) {
      writeInt32(0);
      return;
    }

    TypeEncoder buffer = TypeEncoder();

    for (Object v in value) {
      buffer._writeField(fieldName, v);
    }

    // Now that the length in bytes is known append it to output
    // followed by the buffered data
    writeInt32(buffer.writer.lengthInBytes);
    writer.addLast(buffer.writer.joinChunks());
  }

  void _writeField(String fieldName, Object? value) {
    if (value is Map<String, Object>) {
      writeUInt8(FieldType.FIELD_TABLE.value);
      writeFieldTable(value);
    } else if (value is Iterable) {
      writeUInt8(FieldType.FIELD_ARRAY.value);
      writeArray(fieldName, value);
    } else if (value is bool) {
      writeUInt8(FieldType.BOOLEAN.value);
      writeUInt8(value ? 1 : 0);
    } else if (value is int && value > 0) {
      if (value <= 0xFF) {
        writeUInt8(FieldType.SHORT_SHORT_UINT.value);
        writeUInt8(value);
      } else if (value <= 0xFFFF) {
        writeUInt8(FieldType.SHORT_UINT.value);
        writeUInt16(value);
      } else if (value <= 0xFFFFFFFF) {
        writeUInt8(FieldType.LONG_UINT.value);
        writeUInt32(value);
      } else {
        writeUInt8(FieldType.LONG_LONG_UINT.value);
        writeUInt64(value);
      }
    } else if (value is int && value < 0) {
      if (value >= -0x80) {
        writeUInt8(FieldType.SHORT_SHORT_INT.value);
        writeInt8(value);
      } else if (value >= -0x8000) {
        writeUInt8(FieldType.SHORT_INT.value);
        writeInt16(value);
      } else if (value >= -0x80000000) {
        writeUInt8(FieldType.LONG_INT.value);
        writeInt32(value);
      } else {
        writeUInt8(FieldType.LONG_LONG_INT.value);
        writeInt64(value);
      }
    } else if (value is String) {
      writeUInt8(FieldType.LONG_STRING.value);
      writeLongString(value);
    } else if (value is double) {
      writeUInt8(FieldType.DOUBLE.value);
      writeDouble(value);
    } else if (value is DateTime) {
      writeUInt8(FieldType.TIMESTAMP.value);
      writeTimestamp(value);
    } else if (value == null) {
      writeUInt8(FieldType.VOID.value);
    } else {
      throw ArgumentError(
          "Could not encode field $fieldName with value $value");
    }
  }

//  void dumpToFile(String outputFile) {
//    File file = new File(outputFile);
//    file.writeAsStringSync('');
//    _writer._bufferedChunks.forEach((List<int> chunk) => file.writeAsBytesSync(chunk, mode : FileMode.APPEND));
//  }

  ChunkedOutputWriter get writer => _writer;
}
