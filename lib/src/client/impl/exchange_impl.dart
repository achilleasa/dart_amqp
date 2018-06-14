part of dart_amqp.client;

class _ExchangeImpl implements Exchange {
  String _name;
  final ExchangeType type;
  final _ChannelImpl channel;

  _ExchangeImpl(_ChannelImpl this.channel, this._name, this.type);

  String get name => _name;

  Future<Exchange> delete({bool ifUnused : false, bool noWait : false}) {
    ExchangeDelete deleteRequest = new ExchangeDelete()
      ..reserved_1 = 0
      ..exchange = name
      ..ifUnused = ifUnused
      ..noWait = noWait;

    Completer<Exchange> completer = new Completer<Exchange>();
    channel.writeMessage(deleteRequest, completer : completer, futurePayload : this);
    return completer.future;
  }

  void publish(Object message, String routingKey, { MessageProperties properties, bool mandatory : false, bool immediate : false}) {
    if (!type.isCustom && type != ExchangeType.FANOUT && (routingKey == null || routingKey.isEmpty)) {
      throw new ArgumentError("A valid routing key needs to be specified");
    }

    BasicPublish pubRequest = new BasicPublish()
      ..reserved_1 = 0
      ..routingKey = routingKey
      ..exchange = name
      ..mandatory = mandatory
      ..immediate = immediate;

    channel.writeMessage(pubRequest, properties : properties, payloadContent : message);
  }

  Future<Consumer> bindPrivateQueueConsumer(List<String> routingKeys, {String consumerTag, bool noAck: true}) {
    // Fanout exchanges do not need to specify any keys. Use the default one if none is specified
    if (type == ExchangeType.FANOUT && (routingKeys == null || routingKeys.isEmpty)) {
      routingKeys = [""];
    }

    if ((routingKeys == null || routingKeys.isEmpty)) {
      throw new ArgumentError("One or more routing keys needs to be specified for this exchange type");
    }

    return channel
    .privateQueue()
    .then((Queue queue) {
      return Future
      .forEach(routingKeys, (String routingKey) => queue.bind(this, routingKey))
      .then((_) => queue.consume(consumerTag : consumerTag, noAck : noAck));
    });
  }
}
