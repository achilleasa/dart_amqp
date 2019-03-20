part of dart_amqp.protocol;

class ContentHeader implements Header {
  int classId;
  final int weight = 0;
  int bodySize;

  MessageProperties properties;

  ContentHeader();

  ContentHeader.fromByteData(TypeDecoder decoder) {
    classId = decoder.readUInt16();
    decoder.skipBytes(2); // Skip weight
    bodySize = decoder.readUInt64();

    int propertyMask = decoder.readUInt16();
    if (propertyMask == 0) {
      return;
    }

    properties = MessageProperties();

    // Read properties depending on the property presence mask.
    // Property presense bits are stored from high -> low starting at bit 15
    if (propertyMask & 0x8000 != 0) {
      properties.contentType = decoder.readShortString();
    }
    if (propertyMask & 0x4000 != 0) {
      properties.contentEncoding = decoder.readShortString();
    }
    if (propertyMask & 0x2000 != 0) {
      properties.headers = decoder.readFieldTable("headers");
    }
    if (propertyMask & 0x1000 != 0) {
      properties.deliveryMode = decoder.readUInt8();
    }
    if (propertyMask & 0x800 != 0) {
      properties.priority = decoder.readUInt8();
    }
    if (propertyMask & 0x400 != 0) {
      properties.corellationId = decoder.readShortString();
    }
    if (propertyMask & 0x200 != 0) {
      properties.replyTo = decoder.readShortString();
    }
    if (propertyMask & 0x100 != 0) {
      properties.expiration = decoder.readShortString();
    }
    if (propertyMask & 0x80 != 0) {
      properties.messageId = decoder.readShortString();
    }
    if (propertyMask & 0x40 != 0) {
      properties.timestamp = decoder.readTimestamp();
    }
    if (propertyMask & 0x20 != 0) {
      properties.type = decoder.readShortString();
    }
    if (propertyMask & 0x10 != 0) {
      properties.userId = decoder.readShortString();
    }
    if (propertyMask & 0x8 != 0) {
      properties.appId = decoder.readShortString();
    }
    if (propertyMask & 0x4 != 0) {
      decoder.readShortString();
    }
  }

  void serialize(TypeEncoder encoder) {
    encoder
      ..writeUInt16(classId)
      ..writeUInt16(weight)
      ..writeUInt64(bodySize);

    if (properties == null) {
      encoder.writeUInt16(0);
      return;
    }

    // Build property presense mask
    // Property presense bits are stored from high -> low starting at bit 15
    int propertyMask = 0;
    if (properties.contentType != null) {
      propertyMask |= 1 << 15;
    }
    if (properties.contentEncoding != null) {
      propertyMask |= 1 << 14;
    }
    if (properties.headers != null) {
      propertyMask |= 1 << 13;
    }
    if (properties.deliveryMode != null) {
      propertyMask |= 1 << 12;
    }
    if (properties.priority != null) {
      propertyMask |= 1 << 11;
    }
    if (properties.corellationId != null) {
      propertyMask |= 1 << 10;
    }
    if (properties.replyTo != null) {
      propertyMask |= 1 << 9;
    }
    if (properties.expiration != null) {
      propertyMask |= 1 << 8;
    }
    if (properties.messageId != null) {
      propertyMask |= 1 << 7;
    }
    if (properties.timestamp != null) {
      propertyMask |= 1 << 6;
    }
    if (properties.type != null) {
      propertyMask |= 1 << 5;
    }
    if (properties.userId != null) {
      propertyMask |= 1 << 4;
    }
    if (properties.appId != null) {
      propertyMask |= 1 << 3;
    }

    encoder.writeUInt16(propertyMask);

    if (properties.contentType != null) {
      encoder.writeShortString(properties.contentType);
    }
    if (properties.contentEncoding != null) {
      encoder.writeShortString(properties.contentEncoding);
    }
    if (properties.headers != null) {
      encoder.writeFieldTable(properties.headers);
    }
    if (properties.deliveryMode != null) {
      encoder.writeUInt8(properties.deliveryMode);
    }
    if (properties.priority != null) {
      encoder.writeUInt8(properties.priority);
    }
    if (properties.corellationId != null) {
      encoder.writeShortString(properties.corellationId);
    }
    if (properties.replyTo != null) {
      encoder.writeShortString(properties.replyTo);
    }
    if (properties.expiration != null) {
      encoder.writeShortString(properties.expiration);
    }
    if (properties.messageId != null) {
      encoder.writeShortString(properties.messageId);
    }
    if (properties.timestamp != null) {
      encoder.writeTimestamp(properties.timestamp);
    }
    if (properties.type != null) {
      encoder.writeShortString(properties.type);
    }
    if (properties.userId != null) {
      encoder.writeShortString(properties.userId);
    }
    if (properties.appId != null) {
      encoder.writeShortString(properties.appId);
    }
  }
}
