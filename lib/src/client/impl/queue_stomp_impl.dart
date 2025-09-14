part of "../../client.dart";

class _QueueStompImpl implements Queue {
  @override
  final String name;

  @override
  final _ChannelStompImpl channel;

  @override
  int messageCount;

  @override
  int consumerCount;

  final Map<String, _ConsumerStompImpl> _consumers = <String, _ConsumerStompImpl>{};

  _QueueStompImpl({
    required this.name,
    required this.channel,
    required this.messageCount,
    required this.consumerCount,
  });

  @override
  Future<Queue> delete({bool ifUnused = false, bool ifEmpty = false, bool noWait = false}) {
    // STOMP Limitation: Cannot delete queues via WebSocket
    // Queue deletion must be done via AMQP, Management UI, or backend service
    return Future.error(StateError("STOMP/WebSocket cannot delete queues. Queue '$name' must be deleted via AMQP, Management UI, or backend service."));
  }

  @override
  Future<Queue> purge({bool noWait = false}) {
    return Future.error(StateError(
      "Queue purge is not supported over STOMP/WebSocket. Perform purge via AMQP backend or RabbitMQ Management UI.",
    ));
  }

  @override
  Future<Queue> bind(Exchange exchange, String routingKey, {bool? noWait, Map<String, Object>? arguments}) {
    return Future.error(StateError(
      "Binding queues to exchanges is not supported over STOMP/WebSocket. Configure bindings on the server or via an AMQP backend.",
    ));
  }

  @override
  Future<Queue> unbind(Exchange exchange, String routingKey, {bool? noWait, Map<String, Object>? arguments}) {
    return Future.error(StateError(
      "Unbinding queues from exchanges is not supported over STOMP/WebSocket. Configure on the server or via an AMQP backend.",
    ));
  }

  @override
  void publish(Object message, {MessageProperties? properties, bool mandatory = false, bool immediate = false}) {
    final stompClient = channel.client.stompClient;
    if (stompClient == null || !stompClient.isActive) {
      throw StateError("STOMP client is not connected");
    }

    try {
      // Convert message to string
      String messageBody;
      Map<String, String> headers = {};

      if (message is String) {
        messageBody = message;
        headers['content-type'] = 'text/plain';
      } else if (message is Map || message is Iterable) {
        messageBody = jsonEncode(message);
        headers['content-type'] = 'application/json';
      } else if (message is Uint8List) {
        messageBody = utf8.decode(message);
        headers['content-type'] = 'application/octet-stream';
      } else {
        messageBody = message.toString();
        headers['content-type'] = 'text/plain';
      }

      // Map AMQP message properties to STOMP headers (best-effort e compatível)
      if (properties != null) {
        if (properties.contentType != null) {
          headers['content-type'] = properties.contentType!;
        }
        // message-id não é permitido em SEND
        if (properties.corellationId != null) {
          headers['correlation-id'] = properties.corellationId!;
        }
        if (properties.replyTo != null) {
          // Use destino de fila em STOMP
          headers['reply-to'] = properties.replyTo!.startsWith('/') ? properties.replyTo! : '/queue/${properties.replyTo!}';
        }
        if (properties.timestamp != null) {
          headers['timestamp'] = properties.timestamp!.millisecondsSinceEpoch.toString();
        }
      }

      // Send message via STOMP to explicit queue destination
      stompClient.send(
        destination: '/queue/$name',
        body: messageBody,
        headers: headers,
      );

      messageCount++;
    } catch (e) {
      throw FatalException("Error publishing STOMP message: $e");
    }
  }

  @override
  Future<Consumer> consume({String? consumerTag, bool noLocal = false, bool noAck = true, bool exclusive = false, bool noWait = false, Map<String, Object>? arguments}) {
    // Generate consumer tag if not provided
    consumerTag ??= 'consumer-${DateTime.now().millisecondsSinceEpoch}-${_consumers.length}';

    if (_consumers.containsKey(consumerTag)) {
      return Future.error(StateError("Consumer with tag '$consumerTag' already exists"));
    }

    if (exclusive && _consumers.isNotEmpty) {
      return Future.error(StateError("Queue already has consumers; cannot create exclusive consumer"));
    }

    try {
      final consumer = _ConsumerStompImpl(
        channel,
        this,
        consumerTag,
        '/queue/$name', // Use explicit queue destination
        noAck: noAck,
        subscribeArguments: arguments,
      );

      _consumers[consumerTag] = consumer;
      consumerCount++;

      return Future.value(consumer);
    } catch (e) {
      return Future.error(FatalException("Error creating STOMP consumer: $e"));
    }
  }

  Future _close() {
    final futures = <Future>[];
    for (var consumer in _consumers.values) {
      futures.add(consumer.cancel());
    }

    return Future.wait(futures).then((_) {
      _consumers.clear();
      consumerCount = 0;
    });
  }

  void _handleException(Exception ex) {
    // Forward exception to all consumers
    for (var consumer in _consumers.values) {
      consumer.close();
    }
  }
}
