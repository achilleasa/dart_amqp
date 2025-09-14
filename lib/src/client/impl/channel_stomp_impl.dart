part of "../../client.dart";

class _ChannelStompImpl implements Channel {
  final int _id;
  final _ClientStompImpl client;

  // Channel state
  final Completer<Channel> _channelOpened = Completer<Channel>();
  Completer<Channel>? _channelClosed;
  bool _isOpen = false;

  // Collections
  final Map<String, _QueueStompImpl> _queues = <String, _QueueStompImpl>{};
  final Map<String, _ExchangeStompImpl> _exchanges = <String, _ExchangeStompImpl>{};

  _ChannelStompImpl(this._id, this.client) {
    // For STOMP, channel is immediately available when client is connected
    if (client._isConnected) {
      _isOpen = true;
      _channelOpened.complete(this);
    } else {
      // Wait for client connection
      client.connect().then((_) {
        _isOpen = true;
        if (!_channelOpened.isCompleted) {
          _channelOpened.complete(this);
        }
      }).catchError((error) {
        if (!_channelOpened.isCompleted) {
          _channelOpened.completeError(error);
        }
      });
    }
  }

  @override
  Future<Channel> close() {
    if (_channelClosed != null) {
      return _channelClosed!.future;
    }

    _channelClosed = Completer<Channel>();
    _isOpen = false;

    // Close all consumers and queues
    final futures = <Future>[];

    for (var queue in _queues.values) {
      futures.add(queue._close());
    }

    Future.wait(futures).whenComplete(() {
      _queues.clear();
      _exchanges.clear();
      // Remove this channel from the client's registry to free the id
      client._channels.remove(_id);
      _channelClosed!.complete(this);
    });

    return _channelClosed!.future;
  }

  @override
  Future<Queue> queue(String name, {bool passive = false, bool durable = false, bool exclusive = false, bool autoDelete = false, bool noWait = false, bool declare = true, Map<String, Object>? arguments}) {
    if (!_isOpen) {
      return Future.error(StateError("Channel has been closed; cannot process messages"));
    }

    // STOMP Limitation: Cannot create/declare queues via WebSocket
    // The queue must already exist on the server (created via AMQP, Management UI, or backend)
    if (declare && !passive) {
      return Future.error(StateError("STOMP/WebSocket cannot create queues. Queue '$name' must be pre-created on the server via AMQP, Management UI, or backend service."));
    }

    // For STOMP, we only track existing queue destinations
    final queue = _QueueStompImpl(
      name: name,
      channel: this,
      messageCount: 0,
      consumerCount: 0,
    );

    _queues[name] = queue;
    return Future.value(queue);
  }

  @override
  Future<Queue> privateQueue({bool noWait = false, Map<String, Object>? arguments}) {
    // STOMP Limitation: Cannot create temporary/private queues via WebSocket
    // Private queues must be pre-created on the server or use a pre-existing temp queue pattern
    return Future.error(StateError("STOMP/WebSocket cannot create private/temporary queues. Use a pre-existing queue pattern or create via backend service."));
  }

  @override
  Future<Exchange> exchange(String name, ExchangeType type, {bool passive = false, bool durable = false, bool noWait = false, bool declare = true, Map<String, Object>? arguments}) {
    if (!_isOpen) {
      return Future.error(StateError("Channel has been closed; cannot process messages"));
    }

    // STOMP Limitation: Cannot create/declare exchanges via WebSocket
    // The exchange must already exist on the server (created via AMQP, Management UI, or backend)
    if (declare && !passive) {
      return Future.error(StateError("STOMP/WebSocket cannot create exchanges. Exchange '$name' must be pre-created on the server via AMQP, Management UI, or backend service."));
    }

    // For STOMP, we only track existing exchange destinations
    final exchange = _ExchangeStompImpl(
      name: name,
      type: type,
      channel: this,
    );

    _exchanges[name] = exchange;
    return Future.value(exchange);
  }

  @override
  Future<Channel> qos(int? prefetchSize, int? prefetchCount, {bool global = true}) {
    return Future.error(StateError(
      "QoS (prefetch) is not supported over STOMP/WebSocket. Configure consumer prefetch on the server (AMQP/management) or use an AMQP backend service.",
    ));
  }

  @override
  void ack(int deliveryTag, {bool multiple = false}) {
    throw StateError(
      "Channel-level ACK is not supported over STOMP/WebSocket. Use consumer-level acknowledgment or configure on the server.",
    );
  }

  @override
  Future<Channel> select() {
    return Future.error(StateError(
      "Transactions are not supported over STOMP/WebSocket. Perform transactional operations via AMQP backend or server configuration.",
    ));
  }

  @override
  Future<Channel> commit() {
    return Future.error(StateError(
      "Transactions are not supported over STOMP/WebSocket. Perform transactional operations via AMQP backend or server configuration.",
    ));
  }

  @override
  Future<Channel> rollback() {
    return Future.error(StateError(
      "Transactions are not supported over STOMP/WebSocket. Perform transactional operations via AMQP backend or server configuration.",
    ));
  }

  @override
  Future<Channel> flow(bool active) {
    return Future.error(StateError(
      "Flow control is not supported over STOMP/WebSocket. Configure server-side or use AMQP backend.",
    ));
  }

  @override
  Future<Channel> recover(bool requeue) {
    return Future.error(StateError(
      "Message recovery is not supported over STOMP/WebSocket. Configure server-side or use AMQP backend.",
    ));
  }

  @override
  StreamSubscription<BasicReturnMessage> basicReturnListener(void Function(BasicReturnMessage message) onData, {Function? onError, void Function()? onDone, bool cancelOnError = false}) {
    throw StateError(
      "Basic.return notifications are not supported over STOMP/WebSocket. Use AMQP backend or server-side confirmations.",
    );
  }

  @override
  StreamSubscription<PublishNotification> publishNotifier(void Function(PublishNotification notification) onData, {Function? onError, void Function()? onDone, bool cancelOnError = false}) {
    throw StateError(
      "Publisher confirms are not supported over STOMP/WebSocket. Use AMQP backend if you need confirms.",
    );
  }

  @override
  Future confirmPublishedMessages() {
    return Future.error(StateError(
      "Publisher confirms are not supported over STOMP/WebSocket. Use AMQP backend if you need confirms.",
    ));
  }

  void handleException(Exception ex) {
    // Handle channel-level exceptions
    if (!_channelOpened.isCompleted) {
      _channelOpened.completeError(ex);
    }

    // Forward to all queues
    for (var queue in _queues.values) {
      queue._handleException(ex);
    }
  }

  // Helper used previously to manage queue lifecycle; currently unnecessary
  // and removed to satisfy linter about unused declarations.
}
