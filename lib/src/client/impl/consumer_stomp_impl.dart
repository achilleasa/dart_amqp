part of "../../client.dart";

class _ConsumerStompImpl implements Consumer {
  // https://github.com/dart-lang/linter/issues/2697
  // ignore: prefer_final_fields
  String _tag;
  final _controller = StreamController<AmqpMessage>();
  @override
  final _ChannelStompImpl channel;
  @override
  final _QueueStompImpl queue;

  // STOMP subscription
  StompUnsubscribe? _stompSubscription;
  final String _destination;
  final String? _routingKeyFilter;
  // Subscription options
  final bool _noAck;
  final Map<String, Object>? _subscribeArguments;
  // ignore: unused_field
  String? _subscriptionId;

  @override
  String get tag => _tag;

  _ConsumerStompImpl(
    this.channel,
    this.queue,
    this._tag,
    this._destination, {
    String? routingKeyFilter,
    bool noAck = true,
    Map<String, Object>? subscribeArguments,
  })  : _routingKeyFilter = routingKeyFilter,
        _noAck = noAck,
        _subscribeArguments = subscribeArguments {
    // Subscribe to STOMP destination when consumer is created
    _subscribeToDestination();
  }

  void _subscribeToDestination() {
    final stompClient = channel.client.stompClient;
    if (stompClient != null) {
      // Prepare headers according to RabbitMQ STOMP capabilities
      final Map<String, String> headers = <String, String>{};

      // ACK mode: auto (default) or client/client-individual
      final String ackMode = () {
        final argAck = _subscribeArguments != null ? _subscribeArguments!['ackMode'] : null;
        if (argAck is String && (argAck == 'auto' || argAck == 'client' || argAck == 'client-individual')) {
          return argAck;
        }
        return _noAck ? 'auto' : 'client';
      }();
      headers['ack'] = ackMode;

      // Subscription id (STOMP requires an id for client/client-individual)
      final providedId = (_subscribeArguments != null && _subscribeArguments!['id'] is String) ? _subscribeArguments!['id'] as String : 'sub-${DateTime.now().millisecondsSinceEpoch}-$_tag';
      headers['id'] = providedId;
      _subscriptionId = providedId;

      // RabbitMQ extension: prefetch-count
      if (_subscribeArguments != null && _subscribeArguments!['prefetch-count'] != null) {
        headers['prefetch-count'] = _subscribeArguments!['prefetch-count'].toString();
      }

      // Optional durable semantics if explicitly requested
      if (_subscribeArguments != null && _subscribeArguments!['durable'] == true) {
        headers['durable'] = 'true';
        if (_subscribeArguments!['auto-delete'] == false) {
          headers['auto-delete'] = 'false';
        }
      }

      // Note: STOMP selector removed as RabbitMQ STOMP may not support it reliably
      // We'll rely on client-side filtering instead

      _stompSubscription = stompClient.subscribe(
        destination: _destination,
        callback: _onStompMessage,
        headers: headers,
      );
    }
  }

  void _onStompMessage(StompFrame frame) {
    try {
      // Ignore message if the stream is closed
      if (_controller.isClosed) {
        return;
      }

      // Convert STOMP frame to AmqpMessage
      final messageProperties = MessageProperties();

      // Extract headers from frame if available (assuming frame has headers property)
      Map<String, String>? headers;
      try {
        headers = frame.headers as Map<String, String>?;
      } catch (e) {
        // If frame.headers is not available or has different structure
        headers = null;
      }

      String? ackId;
      if (headers != null) {
        // Map STOMP headers to AMQP message properties
        headers.forEach((key, value) {
          switch (key.toLowerCase()) {
            case 'content-type':
              messageProperties.contentType = value;
              break;
            case 'message-id':
              messageProperties.messageId = value;
              break;
            case 'correlation-id':
              messageProperties.corellationId = value;
              break;
            case 'reply-to':
              messageProperties.replyTo = value;
              break;
            case 'timestamp':
              try {
                messageProperties.timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(value));
              } catch (e) {
                // Ignore invalid timestamp
              }
              break;
            case 'delivery-mode':
              try {
                messageProperties.deliveryMode = int.parse(value);
              } catch (e) {
                // Ignore invalid delivery mode
              }
              break;
            case 'priority':
              try {
                messageProperties.priority = int.parse(value);
              } catch (e) {
                // Ignore invalid priority
              }
              break;
            case 'expiration':
              messageProperties.expiration = value;
              break;
            case 'ack':
              // STOMP 1.2 uses 'ack' header as the id for ACK/NACK frames
              ackId = value;
              break;
          }
        });
        // Fallback for older brokers: use message-id when ack is not provided
        ackId ??= headers['message-id'];
      }

      // Extract routing key from headers or destination
      String? routingKey = headers?['routing-key'];
      if (routingKey == null) {
        // Try to extract from destination pattern
        final parts = _destination.split('/');
        if (parts.length >= 3) {
          routingKey = parts.sublist(2).join('/');
        } else {
          routingKey = _destination;
        }
      }

      // Client-side routing key filtering
      if (_routingKeyFilter != null) {
        if (!_matchesRoutingPattern(_routingKeyFilter!, routingKey)) {
          // Skip this message as it doesn't match the routing pattern
          return;
        }
      }

      // Extract exchange name from destination
      String exchangeName = '';
      final parts = _destination.split('/');
      if (parts.length >= 3) {
        exchangeName = parts[2];
      }

      // Create AmqpMessage from STOMP frame
      final amqpMessage = _AmqpMessageStompImpl(
        consumer: this,
        payload: _extractPayloadFromFrame(frame),
        properties: messageProperties,
        routingKey: routingKey,
        exchangeName: exchangeName,
        ackId: ackId,
      );

      _controller.add(amqpMessage);
    } catch (e) {
      // Forward error to stream
      if (!_controller.isClosed) {
        _controller.addError(e);
      }
    }
  }

  Uint8List _extractPayloadFromFrame(dynamic frame) {
    try {
      // Try to get body from frame
      if (frame.body != null) {
        if (frame.body is String) {
          return Uint8List.fromList((frame.body as String).codeUnits);
        } else if (frame.body is List<int>) {
          return Uint8List.fromList(frame.body as List<int>);
        }
      }
    } catch (e) {
      // If extraction fails, return empty
    }
    return Uint8List(0);
  }

  /// Check if a routing key matches a pattern with wildcards
  bool _matchesRoutingPattern(String pattern, String routingKey) {
    // Handle exact match first (no wildcards)
    if (!pattern.contains('*') && !pattern.contains('#')) {
      return pattern == routingKey;
    }

    // Convert AMQP pattern to regex
    String regexPattern = pattern;

    // Escape special regex characters except * and # and .
    regexPattern = regexPattern.replaceAll(RegExp(r'[+^${}()|[\]\\]'), r'\$&');

    // Convert AMQP wildcards to regex
    regexPattern = regexPattern.replaceAll('*', r'[^.]+'); // * matches one word (not containing dots)
    regexPattern = regexPattern.replaceAll('#', r'.*'); // # matches zero or more words (including dots)

    // Anchor the pattern to match the entire string
    regexPattern = '^$regexPattern\$';

    try {
      final regex = RegExp(regexPattern);
      return regex.hasMatch(routingKey);
    } catch (e) {
      // If regex compilation fails, fall back to exact match
      return pattern == routingKey;
    }
  }

  @override
  StreamSubscription<AmqpMessage> listen(void Function(AmqpMessage event) onData, {Function? onError, void Function()? onDone, bool cancelOnError = false}) => _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future<Consumer> cancel({bool noWait = false}) {
    Completer<Consumer> completer = Completer<Consumer>();

    try {
      // Unsubscribe from STOMP destination
      if (_stompSubscription != null) {
        _stompSubscription!();
        _stompSubscription = null;
      }

      // Close the stream and complete
      close();
      completer.complete(this);
    } catch (e) {
      completer.completeError(e);
    }

    return completer.future;
  }

  void close() {
    // Unsubscribe if not already done
    if (_stompSubscription != null) {
      _stompSubscription!();
      _stompSubscription = null;
    }

    // Close the stream controller
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

// Custom AmqpMessage implementation for STOMP
class _AmqpMessageStompImpl implements AmqpMessage {
  final _ConsumerStompImpl _consumer;
  final Uint8List _payload;
  final MessageProperties? _properties;
  final String? _routingKey;
  final String? _exchangeName;
  final int _deliveryTag;
  final String? _ackId;

  _AmqpMessageStompImpl({
    required _ConsumerStompImpl consumer,
    required Uint8List payload,
    MessageProperties? properties,
    String? routingKey,
    String? exchangeName,
    int? deliveryTag,
    String? ackId,
  })  : _consumer = consumer,
        _payload = payload,
        _properties = properties,
        _routingKey = routingKey,
        _exchangeName = exchangeName,
        _deliveryTag = deliveryTag ?? DateTime.now().millisecondsSinceEpoch,
        _ackId = ackId;

  @override
  Uint8List? get payload => _payload;

  @override
  String get payloadAsString {
    try {
      return utf8.decode(_payload);
    } catch (e) {
      return '';
    }
  }

  @override
  Map get payloadAsJson {
    try {
      final stringPayload = payloadAsString;
      if (stringPayload.isNotEmpty) {
        return jsonDecode(stringPayload) as Map;
      }
    } catch (e) {
      // Invalid JSON
    }
    return {};
  }

  @override
  String? get routingKey => _routingKey;

  @override
  String? get exchangeName => _exchangeName;

  @override
  int get deliveryTag => _deliveryTag;

  @override
  MessageProperties? get properties => _properties;

  @override
  void ack() {
    // For ack:client or ack:client-individual, send ACK frame if possible
    final stompClient = _consumer.channel.client.stompClient;
    if (stompClient != null && _ackId != null) {
      try {
        stompClient.ack(id: _ackId!);
      } catch (_) {
        // Ignore errors; some brokers may auto-ack regardless
      }
    }
  }

  @override
  void reject(bool requeue) {
    // For ack:client or ack:client-individual, send NACK frame if supported
    final stompClient = _consumer.channel.client.stompClient;
    if (stompClient != null && _ackId != null) {
      try {
        // Some STOMP clients do not support requeue flag; send basic NACK
        stompClient.nack(id: _ackId!);
      } catch (_) {
        // Ignore if not supported
      }
    }
  }

  @override
  void reply(Object responseMessage, {MessageProperties? properties, bool mandatory = false, bool immediate = false}) {
    if (_properties?.replyTo == null) {
      throw ArgumentError("No reply-to property specified in received message");
    }

    // For STOMP, reply by sending to the replyTo destination
    final stompClient = _consumer.channel.client.stompClient;
    if (stompClient != null && stompClient.isActive) {
      try {
        String messageBody;
        Map<String, String> headers = {};

        if (responseMessage is String) {
          messageBody = responseMessage;
          headers['content-type'] = 'text/plain';
        } else if (responseMessage is Map || responseMessage is Iterable) {
          messageBody = jsonEncode(responseMessage);
          headers['content-type'] = 'application/json';
        } else if (responseMessage is Uint8List) {
          messageBody = utf8.decode(responseMessage);
          headers['content-type'] = 'application/octet-stream';
        } else {
          messageBody = responseMessage.toString();
          headers['content-type'] = 'text/plain';
        }

        // Set correlation ID if available
        if (_properties?.corellationId != null) {
          headers['correlation-id'] = _properties!.corellationId!;
        }

        stompClient.send(
          destination: _properties!.replyTo!,
          body: messageBody,
          headers: headers,
        );
      } catch (e) {
        throw FatalException("Error sending STOMP reply: $e");
      }
    }
  }
}
