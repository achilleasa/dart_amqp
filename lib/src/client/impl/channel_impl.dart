part of "../../client.dart";

class _ChannelImpl implements Channel {
  // The allocated channel id
  final int channelId;

  final _ClientImpl _client;
  late FrameWriter _frameWriter;
  late Completer<Channel> _channelOpened;
  Completer<Channel>? _channelClosed;
  late ListQueue<Completer> _pendingOperations;
  late ListQueue<Object> _pendingOperationPayloads;
  late Map<String, _ConsumerImpl> _consumers;
  Message? _lastHandshakeMessage;
  Exception? _channelCloseException;
  final _basicReturnStream = StreamController<BasicReturnMessage>.broadcast();

  // Support for delivery confirmations
  late Map<int, _PublishNotificationImpl> _pendingDeliveries;
  late int _nextPublishSeqNo;
  final _publishNotificationStream =
      StreamController<PublishNotification>.broadcast();

  // After receiving a ConnectionTune message with a non-zero heartbeat value,
  // the client initializes heartbeatSendTimer to send heartbeats to the server
  // approximately twice within the agreed upon period.
  Timer? _heartbeatSendTimer;

  _ChannelImpl(this.channelId, this._client) {
    _frameWriter = FrameWriter(_client.tuningSettings);
    _pendingOperations = ListQueue<Completer>();
    _pendingOperationPayloads = ListQueue<Object>();
    _consumers = <String, _ConsumerImpl>{};

    _pendingDeliveries = <int, _PublishNotificationImpl>{};
    _nextPublishSeqNo = 0; // delivery confirmations are disabled

    // If we are opening a user channel signal to the server; otherwise perform connection handshake
    if (channelId > 0) {
      _channelOpened = Completer<Channel>();
      writeMessage(ChannelOpen(),
          completer: _channelOpened, futurePayload: this);
    } else {
      writeProtocolHeader();
    }
  }

  void writeProtocolHeader() {
    _pendingOperations.add(_client._connected!);
    _pendingOperationPayloads.add(this);

    // Transmit handshake
    _frameWriter.writeProtocolHeader(
        _client.settings.amqpProtocolVersion,
        _client.settings.amqpMajorVersion,
        _client.settings.amqpMinorVersion,
        _client.settings.amqpRevision);
    _setPipe();
  }

  void writeHeartbeat() {
    if (_channelClosed != null ||
        (_client._socket == null && _client._webSocketChannel == null)) {
      return; // no-op
    }

    // Transmit heartbeat
    try {
      _frameWriter.writeHeartbeat();
      _setPipe();
    } catch (_) {
      // An exception will be raised if we attempt to send a hearbeat
      // immediately after the connection to the server is lost. We can safely
      // ignore this error; clients will be notified of the lost connection via
      // a raised StateError.
    }
  }

  /// Encode and transmit [message] optionally accompanied by a server frame with [payloadContent].
  ///
  /// A [StateError] will be thrown when trying to write a message to a closed channel
  void writeMessage(Message message,
      {MessageProperties? properties,
      Object? payloadContent,
      Completer? completer,
      Object? futurePayload,
      bool noWait = false}) {
    if (_channelClosed != null && (_channelClosed != completer)) {
      throw _channelCloseException ?? StateError("Channel has been closed");
    }

    // If an op completer is specified add it to the queue unless noWait is set.
    if (completer != null && !noWait) {
      _pendingOperations.addLast(completer);
      _pendingOperationPayloads.addLast(futurePayload ?? true);
    }

    // If this is a publish request and delivery confirmations are enabled
    // add it to the pending delivery list.
    if (message is BasicPublish && _nextPublishSeqNo > 0) {
      _pendingDeliveries[_nextPublishSeqNo] =
          _PublishNotificationImpl(payloadContent, properties, false);
      _nextPublishSeqNo++;
    }

    _frameWriter.writeMessage(channelId, message,
        properties: properties, payloadContent: payloadContent);

    _setPipe();

    // If the noWait flag was specified, complete the future now. The broken
    // will raise any errors asynchronously via the channel or connection.
    if (completer != null && noWait) {
      completer.complete(futurePayload ?? true);
    }
  }

  void _setPipe() {
    if (_client._webSocketChannel != null) {
      _frameWriter.pipe(_client._webSocketChannel!.sink);
    } else if (_client._socket != null) {
      _frameWriter.pipe(_client._socket!);
    } else {
      throw FatalException("Couldn't set pipe");
    }
  }

  /// Implement the handshake flow specified by the AMQP spec by
  /// examining [serverFrame] and generating the appropriate response
  void _processHandshake(DecodedMessage serverMessage) {
    // Handshake process includes the following steps
    // 1) S : ConnectionStart, C : ConnectionStartOk
    // 2) (optional multiple) S : ConnectionSecure, C : ConnectionSecureOk
    // 3) S : ConnectionTune, C : ConnectionTuneOk
    // 4) C : ConnectionOpen, S : ConnectionOpenOk
    switch (serverMessage.message.runtimeType) {
      case ConnectionStart:
        ConnectionStart serverResponse =
            (serverMessage.message as ConnectionStart);

        // Check if the currently supplied authentication provider is supported by the server.
        if (!serverResponse.mechanisms
            .contains(_client.settings.authProvider.saslType)) {
          _client._handleException(FatalException(
              "Selected authentication provider '${_client.settings.authProvider.saslType}' is unsupported by the server (server supports: ${serverResponse.mechanisms})"));
          return;
        }

        ConnectionStartOk clientResponse = ConnectionStartOk()
          ..clientProperties = {
            "product": "Dart AMQP client",
            "version": "0.3.1",
            "platform": "Dart/${Platform.operatingSystem}",
            if (_client.settings.connectionName != null)
              "connection_name": _client.settings.connectionName!,
          }
          ..locale = 'en_US'
          ..mechanism = _client.settings.authProvider.saslType
          ..response = _client.settings.authProvider.answerChallenge(null);

        // Transmit handshake response
        _lastHandshakeMessage = clientResponse;
        writeMessage(clientResponse);
        break;
      case ConnectionSecure:
        ConnectionSecure serverResponse =
            serverMessage.message as ConnectionSecure;

        ConnectionSecureOk clientResponse = ConnectionSecureOk()
          ..response = _client.settings.authProvider
              .answerChallenge(serverResponse.challenge);

        // Transmit handshake response
        _lastHandshakeMessage = clientResponse;
        writeMessage(clientResponse);
        break;
      case ConnectionTune:
        ConnectionTune serverResponse = serverMessage.message as ConnectionTune;

        // Update tuning settings unless our client forces a specific value
        _client.tuningSettings
          ..maxFrameSize = serverResponse.frameMax
          ..maxChannels = _client.tuningSettings.maxChannels > 0
              ? _client.tuningSettings.maxChannels
              : serverResponse.channelMax
          ..heartbeatPeriod = minDuration(
            Duration(seconds: serverResponse.heartbeat),
            _client.tuningSettings.heartbeatPeriod,
          );

        // Respond with the mirrored tuning settings
        ConnectionTuneOk clientResponse = ConnectionTuneOk()
          ..frameMax = serverResponse.frameMax
          ..channelMax = _client.tuningSettings.maxChannels
          ..heartbeat = _client.tuningSettings.heartbeatPeriod.inSeconds;

        _lastHandshakeMessage = clientResponse;
        writeMessage(clientResponse);

        // If heartbeats are enabled, start sending them out periodically
        // from this point onwards approximately twice within the agreed upon
        // period.
        if (_client.tuningSettings.heartbeatPeriod.inSeconds > 0) {
          connectionLogger.info(
              "Enabling heartbeat support (negotiated interval: ${_client.tuningSettings.heartbeatPeriod.inSeconds}s)");

          var interval =
              _client.tuningSettings.heartbeatPeriod.inMilliseconds ~/ 2;
          _heartbeatSendTimer =
              Timer.periodic(Duration(milliseconds: interval), (_) {
            writeHeartbeat();
          });
        }

        // Also respond with a connection open request. The _channelOpened future has already been
        // pushed to the pending operations stack in the constructor so we do not need to do it here
        ConnectionOpen openRequest = ConnectionOpen()
          ..virtualHost = _client.settings.virtualHost;
        _lastHandshakeMessage = clientResponse;
        writeMessage(openRequest);

        break;
      case ConnectionOpenOk:
        _lastHandshakeMessage = null;
        _completeOperation(serverMessage.message);
        break;
      default:
        throw FatalException(
            "Received unexpected message ${serverMessage.message.runtimeType} during handshake");
    }
  }

  /// Close the channel with an optional [replyCode] and [replyText] and return a [Future]
  /// to be completed when the channel is closed. If the channel is closing due to an error
  /// from an incoming [classId] and [methodId] they should be included as well when invoking
  /// this method.
  ///
  /// After closing the channel any attempt to send a message over it will cause a [StateError]
  Future<Channel> _close(
      {ErrorType? replyCode,
      String? replyText,
      int classId = 0,
      int methodId = 0}) {
    // Already closing / closed
    if (_channelClosed != null) {
      return _channelClosed!.future;
    }

    _channelClosed = Completer<Channel>();

    // Channel #0 should close the connection instead of closing the channel
    Message closeRequest;

    if (channelId == 0) {
      _heartbeatSendTimer?.cancel();
      closeRequest = ConnectionClose()
        ..replyCode = replyCode?.value ?? 0
        ..replyText = replyText
        ..classId = classId
        ..methodId = methodId;
    } else {
      closeRequest = ChannelClose()
        ..replyCode = replyCode?.value ?? 0
        ..replyText = replyText
        ..classId = classId
        ..methodId = methodId;
    }
    writeMessage(closeRequest, completer: _channelClosed, futurePayload: this);
    _channelClosed!.future
        .then((_) => _basicReturnStream.close())
        .then((_) => _abortOperationsAndCloseConsumers(ChannelException(
            "Channel closed", channelId, ErrorType.CHANNEL_ERROR)))
        .then((_) => _client._removeChannel(channelId));
    return _channelClosed!.future;
  }

  /// Process an incoming [serverFrame] sent to this channel
  void handleMessage(DecodedMessage serverMessage) {
    if (_client.handshaking) {
      _processHandshake(serverMessage);
      return;
    }

    if (serverMessage is HeartbeatFrameImpl) {
      return;
    }

    switch (serverMessage.message.runtimeType) {
      // Connection
      case ConnectionCloseOk:
        _completeOperation(serverMessage.message);
        break;
      // Channels
      case ChannelClose:
        // Ack the closing of the channel
        writeMessage(ChannelCloseOk());

        _completeOperationWithError(serverMessage.message!);
        break;
      case ChannelOpenOk:
      case ChannelCloseOk:
      case TxSelectOk:
      case TxCommitOk:
      case TxRollbackOk:
      case ChannelFlowOk:
      case BasicRecoverOk:
        _completeOperation(serverMessage.message);
        break;
      case ConfirmSelectOk:
        // When confirmed deliveries get enabled, we use increasing sequence
        // numbers (starting from 1) to match published messages to ACKs/NACKs.
        _nextPublishSeqNo = 1;
        _completeOperation(serverMessage.message);
        break;
      // Queues
      case QueueDeclareOk:
        QueueDeclareOk serverResponse = serverMessage.message as QueueDeclareOk;
        var queueImpl = (_pendingOperationPayloads.first as _QueueImpl)
          .._name = serverResponse.queue ?? "";
        queueImpl._overrideCounts(
            serverResponse.messageCount, serverResponse.consumerCount);

        _completeOperation(serverResponse);
        break;
      case QueueDeleteOk:
      case QueuePurgeOk:
      case QueueBindOk:
      case QueueUnbindOk:
        _completeOperation(serverMessage.message);
        break;
      // Basic
      case BasicQosOk:
        _completeOperation(serverMessage.message);
        break;
      case BasicConsumeOk:
        BasicConsumeOk serverResponse =
            (serverMessage.message as BasicConsumeOk);
        _ConsumerImpl consumer = (_pendingOperationPayloads.first
            as _ConsumerImpl)
          .._tag = serverResponse.consumerTag ?? "";
        _consumers[serverResponse.consumerTag ?? ""] = consumer;
        _completeOperation(serverResponse);
        break;
      case BasicCancelOk:
        BasicCancelOk serverResponse = (serverMessage.message as BasicCancelOk);
        _consumers.remove(serverResponse.consumerTag);
        _completeOperation(serverResponse);
        break;
      case BasicReturn:
        BasicReturn serverResponse = (serverMessage.message as BasicReturn);
        if (_basicReturnStream.hasListener && !_basicReturnStream.isClosed) {
          _basicReturnStream.add(_BasicReturnMessageImpl.fromDecodedMessage(
              serverResponse, serverMessage));
        }
        break;
      case BasicDeliver:
        BasicDeliver serverResponse = (serverMessage.message as BasicDeliver);
        _ConsumerImpl? target = _consumers[serverResponse.consumerTag];

        // no cosumer with tag
        if (target == null) {
          break;
        }

        target.onMessage(serverMessage as DecodedMessageImpl);
        break;
      // Exchange
      case ExchangeDeclareOk:
        _completeOperation(serverMessage.message);
        break;
      case ExchangeDeleteOk:
        _completeOperation(serverMessage.message);
        break;
      // Confirmations
      case BasicAck:
        BasicAck serverResponse = (serverMessage.message as BasicAck);
        _handlePublishConfirmation(
            serverResponse.deliveryTag, true, serverResponse.multiple);
        break;
      case BasicNack:
        BasicNack serverResponse = (serverMessage.message as BasicNack);
        _handlePublishConfirmation(
            serverResponse.deliveryTag, false, serverResponse.multiple);
        break;
    }
  }

  /// Complete a pending operation with [result] after receiving [serverResponse]
  /// from the socket
  void _completeOperation(Message? serverResponse) {
    if (_pendingOperations.isEmpty) {
      return;
    }

    // Complete the first pending operation in the queue with  the first future payload
    _pendingOperations
        .removeFirst()
        .complete(_pendingOperationPayloads.removeFirst());
  }

  /// Complete a pending operation with [error] after receiving [serverResponse]
  /// from the socket
  void _completeOperationWithError(Message serverResponse) {
    Exception? ex;
    switch (serverResponse.runtimeType) {
      case ConnectionClose:
        ConnectionClose closeResponse = serverResponse as ConnectionClose;
        ex = ConnectionException(
            closeResponse.replyText ?? "",
            ErrorType.valueOf(closeResponse.replyCode),
            serverResponse.msgClassId,
            serverResponse.msgMethodId);

        // Complete the first pending operation in the queue with  the first future payload
        _pendingOperationPayloads.removeFirst();
        _pendingOperations.removeFirst().completeError(ex);

        break;
      case ChannelClose:
        ChannelClose closeResponse = serverResponse as ChannelClose;

        // If we got a NOT_FOUND error and we have a pending Queue or Exchange payload emit a QueueNotFoundException
        if (closeResponse.replyCode == ErrorType.NOT_FOUND.value &&
            _pendingOperationPayloads.first is Queue) {
          ex = QueueNotFoundException(closeResponse.replyText ?? "", channelId,
              ErrorType.valueOf(closeResponse.replyCode));
        } else if (closeResponse.replyCode == ErrorType.NOT_FOUND.value &&
            _pendingOperationPayloads.first is Exchange) {
          ex = ExchangeNotFoundException(closeResponse.replyText ?? "",
              channelId, ErrorType.valueOf(closeResponse.replyCode));
        } else {
          ex = ChannelException(closeResponse.replyText ?? "", channelId,
              ErrorType.valueOf(closeResponse.replyCode));
        }

        _channelCloseException = ex;
        handleException(ex);

        break;
    }

    // Complete any first pending operation in the queue with the error
    if (ex != null) {
      while (!_pendingOperations.isEmpty) {
        _pendingOperationPayloads.removeFirst();
        _pendingOperations.removeFirst().completeError(ex);
      }
    }
  }

  /// Abort any pending operations with [exception] and mark the channel as closed
  void handleException(exception) {
    // Ignore exception if we are closed
    if (_channelClosed != null && _channelClosed!.isCompleted) {
      return;
    }

    bool flagChannelAsClosed = false;

    if (exception is FatalException || exception is ChannelException) {
      flagChannelAsClosed = true;
    } else if (exception is ConnectionException) {
      // If this is channel 0 then we need to close the connection with the appropriate error code
      if (channelId == 0) {
        // Close connection (channel 0) with the appropriate error code and consider the operation completed
        _close(
            replyCode: exception.errorType,
            replyText: exception.message,
            classId: exception.classId,
            methodId: exception.methodId);
        _completeOperation(null);
      } else {
        // Non-zero channels should be marked as closed
        flagChannelAsClosed = true;
      }
    }

    // Mark the channel as closed if we need to
    if (flagChannelAsClosed) {
      _channelClosed ??= Completer<Channel>();
      if (!_channelClosed!.isCompleted) {
        _channelClosed!.complete(this);
      }
    }

    if (_client.handshaking) {
      return;
    }
    _abortOperationsAndCloseConsumers(exception);
  }

  void _abortOperationsAndCloseConsumers(Exception exception) {
    // Abort any pending operations unless we are currently opening the channel
    for (Completer completer in _pendingOperations) {
      if (!completer.isCompleted) {
        completer.completeError(exception);
      }
    }
    _pendingOperations.clear();
    _pendingOperationPayloads.clear();

    // Close any active consumers.
    for (_ConsumerImpl consumer in _consumers.values) {
      consumer.close();
    }
    _consumers.clear();
  }

  /// Close the channel and return a [Future<Channel>] to be completed when the channel is closed.
  ///
  /// After closing the channel any attempt to send a message over it will cause a [StateError]
  @override
  Future<Channel> close() =>
      _close(replyCode: ErrorType.SUCCESS, replyText: "Normal shutdown");

  @override
  Future<Queue> queue(String name,
      {bool passive = false,
      bool durable = false,
      bool exclusive = false,
      bool autoDelete = false,
      bool noWait = false,
      bool declare = true,
      Map<String, Object>? arguments}) {
    QueueDeclare queueRequest = QueueDeclare()
      ..reserved_1 = 0
      ..queue = name
      ..passive = passive
      ..durable = durable
      ..exclusive = exclusive
      ..autoDelete = autoDelete
      ..noWait = noWait
      ..arguments = arguments;

    Completer<Queue> opCompleter = Completer<Queue>();

    if (!declare) {
      opCompleter.complete(_QueueImpl(this, name));
      return opCompleter.future;
    }

    writeMessage(queueRequest,
        completer: opCompleter,
        futurePayload: _QueueImpl(this, name),
        noWait: noWait);
    return opCompleter.future;
  }

  @override
  Future<Queue> privateQueue(
      {bool noWait = false, Map<String, Object>? arguments}) {
    QueueDeclare queueRequest = QueueDeclare()
      ..reserved_1 = 0
      ..queue = null
      ..passive = false
      ..durable = false
      ..exclusive = true
      ..autoDelete = false
      ..noWait = noWait
      ..arguments = arguments;

    Completer<Queue> opCompleter = Completer<Queue>();
    writeMessage(queueRequest,
        completer: opCompleter,
        futurePayload: _QueueImpl(this, ""),
        noWait: noWait);
    return opCompleter.future;
  }

  @override
  Future<Exchange> exchange(String name, ExchangeType type,
      {bool passive = false,
      bool durable = false,
      bool noWait = false,
      bool declare = true,
      Map<String, Object>? arguments}) {
    if (name.isEmpty) {
      throw ArgumentError("The name of the exchange cannot be empty");
    }
    ExchangeDeclare exchangeRequest = ExchangeDeclare()
      ..reserved_1 = 0
      ..exchange = name
      ..type = type.value
      ..passive = passive
      ..durable = durable
      ..reserved_2 = false
      ..reserved_3 = false
      ..noWait = noWait
      ..arguments = arguments;

    Completer<Exchange> opCompleter = Completer<Exchange>();

    if (!declare) {
      opCompleter.complete(_ExchangeImpl(this, name, type));
      return opCompleter.future;
    }

    writeMessage(exchangeRequest,
        completer: opCompleter,
        futurePayload: _ExchangeImpl(this, name, type),
        noWait: noWait);
    return opCompleter.future;
  }

  @override
  StreamSubscription<BasicReturnMessage> basicReturnListener(
          void Function(BasicReturnMessage message) onData,
          {Function? onError,
          void Function()? onDone,
          bool cancelOnError = false}) =>
      _basicReturnStream.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future<Channel> qos(int? prefetchSize, int? prefetchCount,
      {bool global = true}) {
    BasicQos qosRequest = BasicQos()
      ..prefetchSize = prefetchSize ?? 0
      ..prefetchCount = prefetchCount ?? 0
      ..global = global;

    Completer<Channel> opCompleter = Completer<Channel>();
    writeMessage(qosRequest, completer: opCompleter, futurePayload: this);
    return opCompleter.future;
  }

  @override
  void ack(int deliveryTag, {bool multiple = false}) {
    BasicAck ackRequest = BasicAck()
      ..deliveryTag = deliveryTag
      ..multiple = multiple;

    writeMessage(ackRequest);
  }

  @override
  Future<Channel> select() {
    TxSelect selectRequest = TxSelect();
    Completer<Channel> opCompleter = Completer<Channel>();
    writeMessage(selectRequest, completer: opCompleter, futurePayload: this);
    return opCompleter.future;
  }

  @override
  Future<Channel> commit() {
    TxCommit commitRequest = TxCommit();
    Completer<Channel> opCompleter = Completer<Channel>();
    writeMessage(commitRequest, completer: opCompleter, futurePayload: this);
    return opCompleter.future;
  }

  @override
  Future<Channel> rollback() {
    TxRollback rollbackRequest = TxRollback();
    Completer<Channel> opCompleter = Completer<Channel>();
    writeMessage(rollbackRequest, completer: opCompleter, futurePayload: this);
    return opCompleter.future;
  }

  @override
  Future<Channel> flow(bool active) {
    ChannelFlow flowRequest = ChannelFlow()..active = active;

    Completer<Channel> opCompleter = Completer<Channel>();
    writeMessage(flowRequest, completer: opCompleter, futurePayload: this);
    return opCompleter.future;
  }

  @override
  Future<Channel> recover(bool requeue) {
    BasicRecover recoverRequest = BasicRecover()..requeue = requeue;

    Completer<Channel> opCompleter = Completer<Channel>();
    writeMessage(recoverRequest, completer: opCompleter, futurePayload: this);
    return opCompleter.future;
  }

  @override
  StreamSubscription<PublishNotification> publishNotifier(
          void Function(PublishNotification notification) onData,
          {Function? onError,
          void Function()? onDone,
          bool cancelOnError = false}) =>
      _publishNotificationStream.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future confirmPublishedMessages() {
    Completer opCompleter = Completer();
    if (_nextPublishSeqNo > 0) {
      opCompleter.complete(); // already enabled
    } else {
      ConfirmSelect confirmRequest = ConfirmSelect();
      writeMessage(confirmRequest, completer: opCompleter);
    }
    return opCompleter.future;
  }

  void _handlePublishConfirmation(int seqNo, bool ack, bool multipleMessages) {
    if (!multipleMessages) {
      // Ack/Nack specific seqNo
      _PublishNotificationImpl? notification = _pendingDeliveries.remove(seqNo);
      if (notification != null &&
          _publishNotificationStream.hasListener &&
          !_publishNotificationStream.isClosed) {
        notification.published = ack;
        _publishNotificationStream.add(notification);
      }
      return;
    }

    // Multi Ack/Nack; messages up to seqNo
    for (var pendingSeqNo in _pendingDeliveries.keys) {
      if (pendingSeqNo > seqNo) {
        // only interested in keys up to pendingSeqNo
        break;
      }

      _PublishNotificationImpl? notification = _pendingDeliveries.remove(seqNo);
      if (notification != null &&
          _publishNotificationStream.hasListener &&
          !_publishNotificationStream.isClosed) {
        notification.published = ack;
        _publishNotificationStream.add(notification);
      }
    }

    return;
  }
}

Duration minDuration(Duration a, b) {
  if (a < b) {
    return a;
  }
  return b;
}
