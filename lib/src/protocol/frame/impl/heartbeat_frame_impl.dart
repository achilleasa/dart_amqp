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

  Message get message => null;

  MessageProperties get properties => null;

  Uint8List get payload => null;

  String get payloadAsString => null;

  Map get payloadAsJson => null;
}
