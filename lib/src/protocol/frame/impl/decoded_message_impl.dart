part of dart_amqp.protocol;

class DecodedMessageImpl implements DecodedMessage {
  @override
  final int channel;
  @override
  final Message message;
  ContentHeader? contentHeader;
  ChunkedOutputWriter? payloadBuffer;
  @override
  Uint8List? payload;

  final DateTime created;

  DecodedMessageImpl(this.channel, this.message):created = DateTime.now();

  @override
  String toString()=>"channel=$channel, message=${message.runtimeType}, age=${DateTime.now().millisecondsSinceEpoch - created.millisecondsSinceEpoch}ms";

  @override
  MessageProperties? get properties => contentHeader?.properties;

  set properties(MessageProperties? properties) {
    if (contentHeader != null) {
      contentHeader!.properties = properties;
    }
  }

  void finalizePayload() {
    if (payloadBuffer != null) {
      payload = payloadBuffer!.joinChunks();
      payloadBuffer!.clear();
    }
  }

  @override
  String get payloadAsString {
    if (payload == null) {
      return "";
    }
    return utf8.decode(payload!);
  }

  @override
  Map get payloadAsJson {
    if (payload == null) {
      return {};
    }
    return json.decode(utf8.decode(payload!));
  }
}
