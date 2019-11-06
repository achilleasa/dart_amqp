part of dart_amqp.client;

class _ExchangeImpl implements Exchange {
  String _name;
  final ExchangeType type;
  final _ChannelImpl channel;

  _ExchangeImpl(this.channel, this._name, this.type);

  String get name => _name;

  Future<Exchange> delete({bool ifUnused = false, bool noWait = false}) {
    ExchangeDelete deleteRequest = ExchangeDelete()
      ..reserved_1 = 0
      ..exchange = name
      ..ifUnused = ifUnused
      ..noWait = noWait;

    Completer<Exchange> completer = Completer<Exchange>();
    channel.writeMessage(deleteRequest,
        completer: completer, futurePayload: this);
    return completer.future;
  }

  void publish(Object message, String routingKey,
      {MessageProperties properties,
      bool mandatory = false,
      bool immediate = false}) {
    if (!type.isCustom &&
        type != ExchangeType.FANOUT &&
        type != ExchangeType.HEADERS &&
        (routingKey == null || routingKey.isEmpty)) {
      throw ArgumentError("A valid routing key needs to be specified");
    }

    BasicPublish pubRequest = BasicPublish()
      ..reserved_1 = 0
      ..routingKey = routingKey
      ..exchange = name
      ..mandatory = mandatory
      ..immediate = immediate;

    channel.writeMessage(pubRequest,
        properties: properties, payloadContent: message);
  }

  Future<Consumer> bindPrivateQueueConsumer(List<String> routingKeys,
      {String consumerTag, bool noAck = true}) async {
    // Fanout and headers exchanges do not need to specify any keys. Use the default one if none is specified
    if ((type == ExchangeType.FANOUT || type == ExchangeType.HEADERS) &&
        (routingKeys == null || routingKeys.isEmpty)) {
      routingKeys = [""];
    }

    if ((routingKeys == null || routingKeys.isEmpty)) {
      throw ArgumentError(
          "One or more routing keys needs to be specified for this exchange type");
    }

    Queue queue = await channel.privateQueue();
    for (String routingKey in routingKeys) {
      await queue.bind(this, routingKey);
    }
    return queue.consume(consumerTag: consumerTag, noAck: noAck);
  }

  Future<Consumer> bindQueueConsumer(String queueName, List<String> routingKeys,
      {String consumerTag, bool noAck = true}) async {
    // Fanout and headers exchanges do not need to specify any keys. Use the default one if none is specified
    if ((type == ExchangeType.FANOUT || type == ExchangeType.HEADERS) &&
        (routingKeys == null || routingKeys.isEmpty)) {
      routingKeys = [""];
    }

    if ((routingKeys == null || routingKeys.isEmpty)) {
      throw ArgumentError(
          "One or more routing keys needs to be specified for this exchange type");
    }

    Queue queue = await channel.queue(queueName);
    for (String routingKey in routingKeys) {
      await queue.bind(this, routingKey);
    }
    return queue.consume(consumerTag: consumerTag, noAck: noAck);
  }
}
