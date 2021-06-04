part of dart_amqp.protocol;

class DecodedMessageImpl implements DecodedMessage {
  @override
  final int channel;
  @override
  final Message message;
  ContentHeader contentHeader;
  ChunkedOutputWriter payloadBuffer;
  @override
  Uint8List payload;

  DecodedMessageImpl(this.channel, this.message);

  @override
  MessageProperties get properties => contentHeader?.properties;

  set properties(MessageProperties properties) {
    if (contentHeader != null) {
      contentHeader.properties = properties;
    }
  }

  void finalizePayload() {
    if (payloadBuffer != null) {
      payload = payloadBuffer.joinChunks();
      payloadBuffer.clear();
    }
  }

//  String toString() {
//    StringBuffer sb = new StringBuffer("""
//DecodedMessage
//------------
//  channel    : ${channel}
//  message    : ${message.toString().replaceAll(new RegExp("\n"), "\n               ")}
//""");
//
//    if (contentHeader != null) {
//      if (properties != null) {
//        sb.write("  properties : ${properties.toString().replaceAll(new RegExp("\n"), "\n           ")}\n");
//      }
//
//      sb.write("  payload : ${contentHeader.bodySize == 0 ? "N/A" : contentHeader.bodySize}\n");
//    }
//
//    return sb.toString();
//  }

  @override
  String get payloadAsString {
    return utf8.decode(payload);
  }

  @override
  Map get payloadAsJson {
    return json.decode(utf8.decode(payload));
  }
}
