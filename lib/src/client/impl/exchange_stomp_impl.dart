part of "../../client.dart";

class _ExchangeStompImpl implements Exchange {
  @override
  final String name;

  @override
  final ExchangeType type;

  @override
  final _ChannelStompImpl channel;

  _ExchangeStompImpl({
    required this.name,
    required this.type,
    required this.channel,
  });

  @override
  Future<Exchange> delete({bool ifUnused = false, bool noWait = false}) {
    return Future.error(StateError(
      "Deleting exchanges is not supported over STOMP/WebSocket. Perform this operation via AMQP backend or RabbitMQ Management UI.",
    ));
  }

  @override
  void publish(Object message, String? routingKey, {MessageProperties? properties, bool mandatory = false, bool immediate = false}) {
    final stompClient = channel.client.stompClient;

    if (stompClient == null || !stompClient.isActive) {
      throw StateError("STOMP client is not connected or not active");
    }

    // Additional check for client state
    if (!channel.client.isConnected) {
      throw StateError("STOMP client connection is not ready");
    }

    try {
      // Build destination for RabbitMQ STOMP plugin
      // Prefer /exchange/{exchange}/{routingKey} so broker applies routing
      String destination;
      if (routingKey != null && routingKey.isNotEmpty) {
        destination = '/exchange/$name/$routingKey';
      } else {
        // Para STOMP/RabbitMQ, enviar sem routing key pode falhar; ainda usamos '/exchange/name' mas alguns brokers ignoram
        destination = '/exchange/$name';
      }

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

      // Map AMQP message properties to STOMP headers (best-effort)
      if (properties != null) {
        if (properties.contentType != null) {
          headers['content-type'] = properties.contentType!;
        }
        // NOTE: 'message-id' is not allowed on SEND frames in STOMP
        // if (properties.messageId != null) {
        //   headers['message-id'] = properties.messageId!;
        // }
        if (properties.corellationId != null) {
          // Not all brokers expose correlation-id via STOMP
          headers['correlation-id'] = properties.corellationId!;
        }
        if (properties.replyTo != null) {
          headers['reply-to'] = properties.replyTo!;
        }
        if (properties.timestamp != null) {
          headers['timestamp'] = properties.timestamp!.millisecondsSinceEpoch.toString();
        }
        // Map delivery mode (persistent/non-persistent)
        // delivery-mode não é padronizado em STOMP; omitimos para compat
        // Map priority
        // priority não é padronizado em STOMP; omitimos
        // Map expiration (TTL)
        // expiration (TTL) não é suportado em STOMP; omitimos
      }

      // No need to add routing-key header when using /exchange/{name}/{rk}

      // Send message via STOMP
      stompClient.send(
        destination: destination,
        body: messageBody,
        headers: headers,
      );
    } catch (e) {
      throw FatalException("Error publishing STOMP message to exchange: $e");
    }
  }

  @override
  Future<Consumer> bindPrivateQueueConsumer(List<String>? routingKeys, {String? consumerTag, bool noAck = true, bool noWait = false, Map<String, Object>? arguments}) {
    // For STOMP, we'll use a simpler approach
    // Create a consumer that subscribes directly to the exchange with routing patterns

    if (routingKeys == null || routingKeys.isEmpty) {
      // No routing keys, create a basic queue consumer
      return channel.privateQueue(arguments: arguments).then((queue) {
        return queue.consume(
          consumerTag: consumerTag,
          noAck: noAck,
          exclusive: true,
          noWait: noWait,
          arguments: arguments,
        );
      });
    }

    // For STOMP with routing keys, subscribe to the proper destination path so the broker routes for us
    final routingKey = routingKeys.first; // Use first routing key for simplicity

    // Generate consumer tag if not provided
    consumerTag ??= 'consumer-${DateTime.now().millisecondsSinceEpoch}';

    // Create a mock queue for compatibility
    final queueName = 'stomp_consumer_${DateTime.now().millisecondsSinceEpoch}';
    final queue = _QueueStompImpl(
      name: queueName,
      channel: channel,
      messageCount: 0,
      consumerCount: 0,
    );

    // Use /exchange/{exchange}/{routingKeyPattern} for all exchanges (including topic)
    // '/topic/{rk}' is an alias for amq.topic only; we keep generic mapping for any exchange name
    String destination = '/exchange/$name/$routingKey';

    return Future.value(_createConsumerWithDestinationSync(
      queue,
      destination,
      routingKey: routingKey,
      consumerTag: consumerTag,
      noAck: noAck,
      exclusive: true,
      noWait: noWait,
      arguments: arguments,
    ));
  }

  Consumer _createConsumerWithDestinationSync(Queue queue, String destination, {String? routingKey, String? consumerTag, bool noAck = true, bool exclusive = false, bool noWait = false, Map<String, Object>? arguments}) {
    // Generate consumer tag if not provided
    consumerTag ??= 'consumer-${DateTime.now().millisecondsSinceEpoch}-${queue.name}';

    final queueImpl = queue as _QueueStompImpl;
    if (queueImpl._consumers.containsKey(consumerTag)) {
      throw StateError("Consumer with tag '$consumerTag' already exists");
    }

    if (exclusive && queueImpl._consumers.isNotEmpty) {
      throw StateError("Queue already has consumers; cannot create exclusive consumer");
    }

    try {
      final consumer = _ConsumerStompImpl(
        channel,
        queueImpl,
        consumerTag,
        destination, // Use the proper destination instead of queue name
        routingKeyFilter: routingKey,
        noAck: noAck,
        subscribeArguments: arguments,
      );

      queueImpl._consumers[consumerTag] = consumer;
      queueImpl.consumerCount++;

      return consumer;
    } catch (e) {
      throw FatalException("Error creating STOMP consumer: $e");
    }
  }

  @override
  Future<Consumer> bindQueueConsumer(String queueName, List<String> routingKeys, {String? consumerTag, bool noAck = true, bool passive = false, bool durable = false, bool exclusive = false, bool autoDelete = false, bool noWait = false, bool declare = true}) {
    if (declare && !passive) {
      return Future.error(StateError(
        "Declaring queues/exchanges is not supported over STOMP/WebSocket. Provision them on the server (AMQP/backend) and connect with passive=true.",
      ));
    }

    // Consume from an existing queue (must be pre-provisioned server-side)
    return channel.queue(queueName, passive: true, durable: durable, exclusive: exclusive, autoDelete: autoDelete, noWait: noWait, declare: false).then((queue) {
      return queue.consume(
        consumerTag: consumerTag,
        noAck: noAck,
        exclusive: exclusive,
        noWait: noWait,
      );
    });
  }
}
