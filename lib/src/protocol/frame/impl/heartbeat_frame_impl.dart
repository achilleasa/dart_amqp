part of "../../../protocol.dart";

class HeartbeatFrameImpl implements DecodedMessage {
  @override
  final int channel;

  HeartbeatFrameImpl(this.channel);

  @override
  Message? get message => null;

  @override
  MessageProperties? get properties => null;

  @override
  Uint8List get payload => Uint8List(0);

  @override
  String get payloadAsString => "";

  @override
  Map get payloadAsJson => {};
}
