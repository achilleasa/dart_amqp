part of dart_amqp.protocol;

class HeartbeatFrameImpl implements DecodedMessage {
  final int channel;

  HeartbeatFrameImpl(this.channel);

//  String toString() {
//    StringBuffer sb = new StringBuffer("""
//HeartbeatFrame
//------------
//  channel    : ${channel}
//""");
//
//    return sb.toString();
//  }

  Message get message => HeartbeatMessage();

  MessageProperties get properties => null;

  Uint8List get payload => null;

  String get payloadAsString => null;

  Map get payloadAsJson => null;
}

class HeartbeatMessage implements Message {
  final bool msgHasContent = false;
  final int msgClassId = 0;
  final int msgMethodId = 0;

  HeartbeatMessage();
  HeartbeatMessage.fromStream(TypeDecoder decoder) {}
  void serialize(TypeEncoder encoder) {
    encoder..writeUInt16(msgClassId)..writeUInt16(msgMethodId);
  }
}
