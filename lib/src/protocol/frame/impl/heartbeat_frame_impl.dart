part of dart_amqp.protocol;

class HeartbeatFrameImpl implements DecodedMessage {
  @override
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

  @override
  Message get message => null;

  @override
  MessageProperties get properties => null;

  @override
  Uint8List get payload => null;

  @override
  String get payloadAsString => null;

  @override
  Map get payloadAsJson => null;
}
