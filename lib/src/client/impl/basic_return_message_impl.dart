part of dart_amqp.client;

class _BasicReturnMessageImpl implements BasicReturnMessage {
  final DecodedMessage message;
  final BasicReturn basicReturn;

  _BasicReturnMessageImpl.fromDecodedMessage(this.basicReturn, this.message);

  @override
  Uint8List? get payload => message.payload;

  @override
  String? get payloadAsString => message.payloadAsString;

  @override
  Map? get payloadAsJson => message.payloadAsJson;

  @override
  String get exchangeName => basicReturn.exchange;

  @override
  String get routingKey => basicReturn.routingKey;

  @override
  int get replyCode => basicReturn.replyCode;

  @override
  String get replyText => basicReturn.replyText;

  @override
  MessageProperties? get properties => message.properties;
}
