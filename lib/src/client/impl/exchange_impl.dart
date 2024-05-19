part of "../../client.dart";

class _ExchangeImpl implements Exchange {
  final String _name;
  @override
  final ExchangeType type;
  @override
  final _ChannelImpl channel;

  _ExchangeImpl(this.channel, this._name, this.type);

  @override
  String get name => _name;

  @override
  Future<Exchange> delete({bool ifUnused = false, bool noWait = false}) {
    ExchangeDelete deleteRequest = ExchangeDelete()
      ..reserved_1 = 0
      ..exchange = name
      ..ifUnused = ifUnused
      ..noWait = noWait;

    Completer<Exchange> completer = Completer<Exchange>();
    channel.writeMessage(deleteRequest,
        completer: completer, futurePayload: this, noWait: noWait);
    return completer.future;
  }

  @override
  void publish(Object message, String? routingKey,
      {MessageProperties? properties,
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

  @override
  Future<Consumer> bindPrivateQueueConsumer(
    List<String>? routingKeys, {
    String? consumerTag,
    bool noAck = true,
    bool noWait = false,
    Map<String, Object>? arguments,
  }) async {
    // Fanout and headers exchanges do not need to specify any keys. Use the default one if none is specified
    if ((type == ExchangeType.FANOUT || type == ExchangeType.HEADERS) &&
        (routingKeys == null || routingKeys.isEmpty)) {
      routingKeys = [""];
    }

    if ((routingKeys == null || routingKeys.isEmpty)) {
      throw ArgumentError(
          "One or more routing keys needs to be specified for this exchange type");
    }

    Queue queue =
        await channel.privateQueue(noWait: noWait, arguments: arguments);
    for (String routingKey in routingKeys) {
      await queue.bind(this, routingKey);
    }
    return queue.consume(consumerTag: consumerTag, noAck: noAck);
  }

  @override
  Future<Consumer> bindQueueConsumer(
    String queueName,
    List<String>? routingKeys, {
    String? consumerTag,
    bool noAck = true,
    bool passive = false,
    bool durable = false,
    bool exclusive = false,
    bool autoDelete = false,
    bool noWait = false,
    bool declare = true,
  }) async {
    // Fanout and headers exchanges do not need to specify any keys. Use the default one if none is specified
    if ((type == ExchangeType.FANOUT || type == ExchangeType.HEADERS) &&
        (routingKeys == null || routingKeys.isEmpty)) {
      routingKeys = [""];
    }

    if ((routingKeys == null || routingKeys.isEmpty)) {
      throw ArgumentError(
          "One or more routing keys needs to be specified for this exchange type");
    }

    Queue queue = await channel.queue(queueName,
        passive: passive,
        durable: durable,
        exclusive: exclusive,
        autoDelete: autoDelete,
        noWait: noWait,
        declare: declare);
    for (String routingKey in routingKeys) {
      await queue.bind(this, routingKey);
    }
    return queue.consume(consumerTag: consumerTag, noAck: noAck);
  }
}
