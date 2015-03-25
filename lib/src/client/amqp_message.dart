part of dart_amqp.client;

abstract class AmqpMessage {
  Uint8List get payload;

  String get payloadAsString;

  Map get payloadAsJson;

  String get exchangeName;

  String get routingKey;

  MessageProperties get properties;

  void ack();

  void reply(Object responseMessage, {MessageProperties properties, bool mandatory : false, bool immediate : false});

  void reject(bool requeue);
}