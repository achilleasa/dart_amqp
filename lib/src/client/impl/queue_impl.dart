part of dart_amqp.client;

class _QueueImpl implements Queue {
  String _name;
  int _messageCount;
  int _consumerCount;
  final _ChannelImpl channel;

  _QueueImpl(_ChannelImpl this.channel, this._name);

  String get name => _name;

  int get messageCount => _messageCount;

  int get consumerCount => _consumerCount;

  Future<Queue> delete({bool ifUnused : false, bool IfEmpty : false, bool noWait : false}) {
    QueueDelete deleteRequest = new QueueDelete()
      ..reserved_1 = 0
      ..queue = name
      ..ifUnused = ifUnused
      ..ifEmpty = IfEmpty
      ..noWait = noWait;

    Completer completer = new Completer();
    channel.writeMessage(deleteRequest, completer : completer, futurePayload : this);
    return completer.future;
  }

  Future<Queue> purge({bool noWait : false}) {
    QueuePurge purgeRequest = new QueuePurge()
      ..reserved_1 = 0
      ..queue = name
      ..noWait = noWait;

    Completer completer = new Completer();
    channel.writeMessage(purgeRequest, completer : completer, futurePayload : this);
    return completer.future;
  }

  Future<Queue> bind(Exchange exchange, String routingKey, {bool noWait, Map<String, Object> arguments}) {
    if (exchange == null) {
      throw new ArgumentError("Exchange cannot be null");
    }
    // Fanout exchanges do not need to specify any keys. Use the default one if none is specified
    if (routingKey == null || routingKey.isEmpty) {
      if (exchange.type == ExchangeType.FANOUT) {
        routingKey = "";
      } else {
        throw new ArgumentError("A routing key needs to be specified to bind to this exchange type");
      }
    }

    QueueBind bindRequest = new QueueBind()
      ..reserved_1 = 0
      ..queue = name
      ..exchange = exchange.name
      ..routingKey = routingKey
      ..noWait = noWait;

    Completer completer = new Completer();
    channel.writeMessage(bindRequest, completer : completer, futurePayload : this);
    return completer.future;
  }

  Future<Queue> unbind(Exchange exchange, String routingKey, {bool noWait, Map<String, Object> arguments}) {
    if (exchange == null) {
      throw new ArgumentError("Exchange cannot be null");
    }
    // Fanout exchanges do not need to specify any keys. Use the default one if none is specified
    if (routingKey == null || routingKey.isEmpty) {
      if (exchange.type == ExchangeType.FANOUT) {
        routingKey = "";
      } else {
        throw new ArgumentError("A routing key needs to be specified to unbind from this exchange type");
      }
    }

    QueueUnbind unbindRequest = new QueueUnbind()
      ..reserved_1 = 0
      ..queue = name
      ..exchange = exchange.name
      ..routingKey = routingKey;

    Completer completer = new Completer();
    channel.writeMessage(unbindRequest, completer : completer, futurePayload : this);
    return completer.future;
  }

  void publish(Object message, { MessageProperties properties, bool mandatory : false, bool immediate : false}) {
    BasicPublish pubRequest = new BasicPublish()
      ..reserved_1 = 0
      ..routingKey = name // send to this queue
      ..exchange = "" // default exchange
      ..mandatory = mandatory
      ..immediate = immediate;

    channel.writeMessage(pubRequest, properties : properties, payloadContent : message);
  }

  Future<Consumer> consume({String consumerTag, bool noLocal : false, bool noAck: true, bool exclusive : false, bool noWait : false, Map<String, Object> arguments}) {
    // If a consumer with the requested tag exists, return that
    if (consumerTag != null && !consumerTag.isEmpty && channel._consumers.containsKey(consumerTag)) {
      return new Future.value(channel._consumers[consumerTag]);
    }

    BasicConsume consumeRequest = new BasicConsume()
      ..reserved_1 = 0
      ..queue = name
      ..consumerTag = consumerTag
      ..noLocal = noLocal
      ..noAck = noAck
      ..noWait = noWait
      ..exclusive = exclusive
      ..arguments = arguments;

    Completer completer = new Completer();
    channel.writeMessage(consumeRequest, completer : completer, futurePayload : new _ConsumerImpl(channel, this, ""));
    return completer.future;
  }

}
