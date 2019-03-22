part of dart_amqp.protocol;

class ProtocolHeader implements Header {
  static const int LENGTH_IN_BYTES = 8;

  int protocolVersion;
  int majorVersion;
  int minorVersion;
  int revision;

  ProtocolHeader();

  ProtocolHeader.fromByteData(TypeDecoder decoder) {
    // Skip AMQP string
    decoder.skipBytes(4);
    protocolVersion = decoder.readUInt8();
    majorVersion = decoder.readUInt8();
    minorVersion = decoder.readUInt8();
    revision = decoder.readUInt8();
  }

  void serialize(TypeEncoder encoder) {
    encoder
      ..writer.addLast(Uint8List.fromList(ascii.encode("AMQP")))
      ..writeUInt8(protocolVersion)
      ..writeUInt8(majorVersion)
      ..writeUInt8(minorVersion)
      ..writeUInt8(revision);
  }
}
