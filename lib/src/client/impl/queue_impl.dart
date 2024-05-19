part of "../../client.dart";

class _QueueImpl implements Queue {
  // https://github.com/dart-lang/linter/issues/2697
  // ignore: prefer_final_fields
  String _name;
  int _messageCount = 0;
  int _consumerCount = 0;
  @override
  final _ChannelImpl channel;

  _QueueImpl(this.channel, this._name);

  @override
  String get name => _name;

  @override
  int get messageCount => _messageCount;

  @override
  int get consumerCount => _consumerCount;

  @override
  Future<Queue> delete(
      {bool ifUnused = false, bool ifEmpty = false, bool noWait = false}) {
    QueueDelete deleteRequest = QueueDelete()
      ..reserved_1 = 0
      ..queue = name
      ..ifUnused = ifUnused
      ..ifEmpty = ifEmpty
      ..noWait = noWait;

    Completer<Queue> completer = Completer<Queue>();
    channel.writeMessage(deleteRequest,
        completer: completer, futurePayload: this, noWait: noWait);
    return completer.future;
  }

  @override
  Future<Queue> purge({bool noWait = false}) {
    QueuePurge purgeRequest = QueuePurge()
      ..reserved_1 = 0
      ..queue = name
      ..noWait = noWait;

    Completer<Queue> completer = Completer<Queue>();
    channel.writeMessage(purgeRequest,
        completer: completer, futurePayload: this, noWait: noWait);
    return completer.future;
  }

  @override
  Future<Queue> bind(Exchange? exchange, String? routingKey,
      {bool noWait = false, Map<String, Object>? arguments}) {
    if (exchange == null) {
      throw ArgumentError("Exchange cannot be null");
    }
    // Fanout and headers exchanges do not need to specify any keys. Use the default one if none is specified
    if (routingKey == null || routingKey.isEmpty) {
      if (exchange.type == ExchangeType.FANOUT ||
          exchange.type == ExchangeType.HEADERS) {
        routingKey = "";
      } else {
        throw ArgumentError(
            "A routing key needs to be specified to bind to this exchange type");
      }
    }

    QueueBind bindRequest = QueueBind()
      ..reserved_1 = 0
      ..queue = name
      ..exchange = exchange.name
      ..routingKey = routingKey
      ..noWait = noWait
      ..arguments = arguments;

    Completer<Queue> completer = Completer<Queue>();
    channel.writeMessage(bindRequest,
        completer: completer, futurePayload: this, noWait: noWait);
    return completer.future;
  }

  @override
  Future<Queue> unbind(Exchange exchange, String? routingKey,
      {bool noWait = false, Map<String, Object>? arguments}) {
    // Fanout and headers exchanges do not need to specify any keys. Use the default one if none is specified
    if (routingKey == null || routingKey.isEmpty) {
      if (exchange.type == ExchangeType.FANOUT ||
          exchange.type == ExchangeType.HEADERS) {
        routingKey = "";
      } else {
        throw ArgumentError(
            "A routing key needs to be specified to unbind from this exchange type");
      }
    }

    QueueUnbind unbindRequest = QueueUnbind()
      ..reserved_1 = 0
      ..queue = name
      ..exchange = exchange.name
      ..routingKey = routingKey
      ..arguments = arguments;

    Completer<Queue> completer = Completer<Queue>();
    channel.writeMessage(unbindRequest,
        completer: completer, futurePayload: this, noWait: noWait);
    return completer.future;
  }

  @override
  void publish(Object message,
      {MessageProperties? properties,
      bool mandatory = false,
      bool immediate = false}) {
    BasicPublish pubRequest = BasicPublish()
      ..reserved_1 = 0
      ..routingKey = name // send to this queue
      ..exchange = "" // default exchange
      ..mandatory = mandatory
      ..immediate = immediate;

    channel.writeMessage(pubRequest,
        properties: properties, payloadContent: message);
  }

  @override
  Future<Consumer> consume(
      {String? consumerTag,
      bool noLocal = false,
      bool noAck = true,
      bool exclusive = false,
      bool noWait = false,
      Map<String, Object>? arguments}) {
    // If a consumer with the requested tag exists, return that
    if (consumerTag != null &&
        consumerTag.isNotEmpty &&
        channel._consumers.containsKey(consumerTag)) {
      return Future.value(channel._consumers[consumerTag]);
    }

    BasicConsume consumeRequest = BasicConsume()
      ..reserved_1 = 0
      ..queue = name
      ..consumerTag = consumerTag
      ..noLocal = noLocal
      ..noAck = noAck
      ..noWait = noWait
      ..exclusive = exclusive
      ..arguments = arguments;

    Completer<Consumer> completer = Completer<Consumer>();
    channel.writeMessage(consumeRequest,
        completer: completer,
        futurePayload: _ConsumerImpl(channel, this, ""),
        noWait: noWait);
    return completer.future;
  }

  void _overrideCounts(int msgCount, int consumerCount) {
    _messageCount = msgCount;
    _consumerCount = consumerCount;
  }
}
