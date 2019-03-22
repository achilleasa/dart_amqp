part of dart_amqp.protocol;

class FrameHeader implements Header {
  static const int LENGTH_IN_BYTES = 7;

  FrameType type;
  int channel;
  int size;

  FrameHeader();

  FrameHeader.fromByteData(TypeDecoder decoder) {
    int typeValue = decoder.readUInt8();
    try {
      type = FrameType.valueOf(typeValue);
    } catch (e) {
      throw FatalException(
          "Received unknown frame type 0x${typeValue.toRadixString(16)}");
    }
    channel = decoder.readUInt16();
    size = decoder.readUInt32();
  }

  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt8(type.value)
      ..writeUInt16(channel)
      ..writeUInt32(size);
  }

//  String toString() {
//    return """
//FrameHeader
//-----------
//  type    : ${FrameType.nameOf(type)}
//  channel : ${channel}
//  size    : ${size}""";
//  }
}
