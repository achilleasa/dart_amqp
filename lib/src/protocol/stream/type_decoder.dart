part of "../../protocol.dart";

class TypeDecoder {
  int _offset = 0;
  final ByteData _buffer;
  final Endian endianess = Endian.big;

  TypeDecoder.fromBuffer(this._buffer);

  int readInt8() {
    return _buffer.getInt8(_offset++);
  }

  int readUInt8() {
    return _buffer.getUint8(_offset++);
  }

  int readUInt16() {
    int val = _buffer.getUint16(_offset, endianess);
    _offset += 2;

    return val;
  }

  int readInt16() {
    int val = _buffer.getInt16(_offset, endianess);
    _offset += 2;

    return val;
  }

  int readUInt32() {
    int val = _buffer.getUint32(_offset, endianess);
    _offset += 4;

    return val;
  }

  int readInt32() {
    int val = _buffer.getInt32(_offset, endianess);
    _offset += 4;

    return val;
  }

  int readUInt64() {
    final int val;
    const kIsWeb = bool.fromEnvironment('dart.library.js_util');
    if (kIsWeb) {
      val = Uint64Converter.getUint64(_buffer, _offset);
    } else {
      val = _buffer.getUint64(_offset, endianess);
    }

    _offset += 8;

    return val;
  }

  int readInt64() {
    int val = _buffer.getInt64(_offset, endianess);
    _offset += 8;

    return val;
  }

  double readFloat() {
    double val = _buffer.getFloat32(_offset, endianess);
    _offset += 4;

    return val;
  }

  double readDouble() {
    double val = _buffer.getFloat64(_offset, endianess);
    _offset += 8;

    return val;
  }

  void skipBytes(int len) {
    _offset += len;
  }

  String readShortString() {
    int len = readUInt8();
    _offset += len;
    return utf8.decode(Uint8List.view(_buffer.buffer, _offset - len, len));
  }

  String readLongString() {
    int len = readUInt32();
    _offset += len;
    return utf8.decode(Uint8List.view(_buffer.buffer, _offset - len, len));
  }

  DateTime? readTimestamp() {
    int value = readUInt64();
    return value > 0 ? DateTime.fromMillisecondsSinceEpoch(value * 1000) : null;
  }

  Iterable readArray(String fieldName) {
    int arrayEndOffset = readInt32() + _offset;
    List items = [];
    while (_offset < arrayEndOffset) {
      items.add(_readField(fieldName));
    }
    return items;
  }

  Map<String, Object?> readFieldTable(String fieldName) {
    int tableEndOffset = readInt32() + _offset;
    var items = HashMap<String, Object?>();
    while (_offset < tableEndOffset) {
      items[readShortString()] = _readField(fieldName);
    }
    return items;
  }

  Object? _readField(String fieldName) {
    int typeValue = readUInt8();
    FieldType type;
    try {
      type = FieldType.valueOf(typeValue);
    } catch (_) {
      return null;
    }

    switch (type) {
      case FieldType.BOOLEAN:
        return readUInt8() == 1;
      case FieldType.SHORT_SHORT_INT:
        return readInt8();
      case FieldType.SHORT_SHORT_UINT:
        return readUInt8();
      case FieldType.SHORT_INT:
        return readInt16();
      case FieldType.SHORT_UINT:
        return readUInt16();
      case FieldType.LONG_INT:
        return readInt32();
      case FieldType.LONG_UINT:
        return readUInt32();
      case FieldType.LONG_LONG_INT:
        return readInt64();
      case FieldType.LONG_LONG_UINT:
        return readUInt64();
      case FieldType.FLOAT:
        return readFloat();
      case FieldType.DOUBLE:
        return readDouble();
      case FieldType.DECIMAL:
        throw ArgumentError("Not implemented");
      case FieldType.SHORT_STRING:
        return readShortString();
      case FieldType.LONG_STRING:
        return readLongString();
      case FieldType.FIELD_ARRAY:
        return readArray(fieldName);
      case FieldType.TIMESTAMP:
        return readTimestamp();
      case FieldType.FIELD_TABLE:
        return readFieldTable(fieldName);
      case FieldType.VOID:
        return null;
      default:
        throw ArgumentError(
            "Could not decode field $fieldName with type 0x${typeValue.toRadixString(16)}");
    }
  }
}
