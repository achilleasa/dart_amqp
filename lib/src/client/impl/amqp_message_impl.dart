part of dart_amqp.client;

class _AmqpMessageImpl implements AmqpMessage {
  final _ConsumerImpl consumer;
  final DecodedMessage message;

  MessageProperties get properties => message.properties;

  _AmqpMessageImpl.fromDecodedMessage(this.consumer, this.message);

  Uint8List get payload => message.payload;

  String get payloadAsString => message.payloadAsString;

  Map get payloadAsJson => message.payloadAsJson;

  String get exchangeName => (message.message as BasicDeliver).exchange;

  String get routingKey => (message.message as BasicDeliver).routingKey;

  void reply(Object responseMessage,
      {MessageProperties properties,
      bool mandatory = false,
      bool immediate = false}) {
    if (message.properties.replyTo == null) {
      throw ArgumentError(
          "No reply-to property specified in the incoming message");
    }

    MessageProperties responseProperties =
        properties == null ? MessageProperties() : properties;

    responseProperties.corellationId = message.properties.corellationId;

    BasicPublish pubRequest = BasicPublish()
      ..reserved_1 = 0
      ..routingKey = message.properties.replyTo // send to 'reply-to'
      ..exchange = ""
      ..mandatory = mandatory
      ..immediate = immediate;

    consumer.channel.writeMessage(pubRequest,
        properties: responseProperties, payloadContent: responseMessage);
  }

  void reject(bool requeue) {
    BasicReject rejectRequest = BasicReject()
      ..deliveryTag = (message.message as BasicDeliver).deliveryTag
      ..requeue = requeue;

    consumer.channel.writeMessage(rejectRequest);
  }

  void ack() {
    consumer.channel.ack((message.message as BasicDeliver).deliveryTag);
  }
}
