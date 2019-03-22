part of dart_amqp.client;

class _BasicReturnMessageImpl implements BasicReturnMessage {
  final DecodedMessage message;
  final BasicReturn basicReturn;

  _BasicReturnMessageImpl.fromDecodedMessage(this.basicReturn, this.message);

  Uint8List get payload => message.payload;

  String get payloadAsString => message.payloadAsString;

  Map get payloadAsJson => message.payloadAsJson;

  String get exchangeName => basicReturn.exchange;

  String get routingKey => basicReturn.routingKey;

  int get replyCode => basicReturn.replyCode;

  String get replyText => basicReturn.replyText;

  MessageProperties get properties => message.properties;
}
