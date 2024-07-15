part of "../../client.dart";

class _ClientImpl implements Client {
  // Configuration options
  @override
  late BaseConnectionSettings settings;

  // Tuning settings
  @override
  TuningSettings get tuningSettings => settings.tuningSettings;

  // The connection to the server
  int _connectionAttempt = 0;
  Socket? _socket;
  WebSocketChannel? _webSocketChannel;

  // The list of open channels. Channel 0 is always reserved for signaling
  final Map<int, _ChannelImpl> _channels = <int, _ChannelImpl>{};

  // Connection status
  Completer? _connected;
  Completer? _clientClosed;

  // Error Stream
  final _error = StreamController<Exception>.broadcast();

  // The heartbeattRecvTimer is reset every time we receive _any_ message from
  // the server. If the timer expires, and a HeartbeatFailed exception will be
  // raised.
  //
  // The timer is set to a multiple of the negotiated interval to reset the
  // connection if we have not received any message from the server for a
  // consecutive number of maxMissedHeartbeats (see tuningSettings).
  RestartableTimer? _heartbeatRecvTimer;

  _ClientImpl({BaseConnectionSettings? settings}) {
    // Use defaults if no settings specified
    this.settings = settings ?? ConnectionSettings();
  }

  /// Attempt to reconnect to the server. If the attempt fails, it will be retried after
  /// [reconnectWaitTime] ms up to [maxConnectionAttempts] times. If all connection attempts
  /// fail, then the [_connected] [Future] returned by a call to [open[ will also fail

  Future _reconnect() {
    _connected ??= Completer();

    Future<Socket>? fs;
    if (settings.uri != null) {
      try {
        connectionLogger.info(
            "Trying to connect to ${settings.uri} [attempt ${_connectionAttempt + 1}/${settings.maxConnectionAttempts}]");
        WebSocketChannel webSocketChannel =
            WebSocketChannel.connect(settings.uri!);

        webSocketChannel.ready.then(
          (value) {
            _webSocketChannel = webSocketChannel;

            // Bind processors and initiate handshake
            _bindProcessorsAndInitHandshake(_webSocketChannel!.stream);

            // Allocate channel 0 for handshaking and transmit the AMQP header to bootstrap the handshake
            _allocateChannelZero();
          },
        ).catchError((err, trace) {
          _reconnectionOnError();
        });
      } catch (_) {
        print("Can't connect to ${settings.uri}");
      }
    } else if (settings.tlsContext != null && _isHostAndPortSet) {
      connectionLogger.info(
          "Trying to connect to ${settings.host}:${settings.port} using TLS [attempt ${_connectionAttempt + 1}/${settings.maxConnectionAttempts}]");
      fs = SecureSocket.connect(
        settings.host,
        settings.port!,
        timeout: settings.connectTimeout,
        context: settings.tlsContext,
        onBadCertificate: settings.onBadCertificate,
      );
    } else if (_isHostAndPortSet) {
      connectionLogger.info(
          "Trying to connect to ${settings.host}:${settings.port} [attempt ${_connectionAttempt + 1}/${settings.maxConnectionAttempts}]");
      fs = Socket.connect(settings.host, settings.port!,
          timeout: settings.connectTimeout);
    } else {
      throw throw ArgumentError(
          "Specify websocketUri to connect through websocket or set host and port to use default connection");
    }

    fs?.then((Socket s) {
      _socket = s;

      // Bind processors and initiate handshake
      _bindProcessorsAndInitHandshake(_socket!);

      // Allocate channel 0 for handshaking and transmit the AMQP header to bootstrap the handshake
      _allocateChannelZero();
    }).catchError((err, trace) {
      _reconnectionOnError();
    });

    return _connected!.future;
  }

  void _bindProcessorsAndInitHandshake(Stream stream) {
    RawFrameParser(tuningSettings)
        .transformer
        .bind(stream)
        .transform(AmqpMessageDecoder().transformer)
        .listen(_handleMessage,
            onError: _handleException,
            onDone: () =>
                _handleException(const SocketException("Socket closed")));
  }

  void _allocateChannelZero() {
    _channels.clear();
    _channels.putIfAbsent(0, () => _ChannelImpl(0, this));
  }

  bool get _isHostAndPortSet => settings.host != null && settings.port != null;

  Future _reconnectionOnError() async {
    // Connection attempt completed with an error (probably protocol mismatch)
    if (_connected!.isCompleted) {
      return;
    }

    if (++_connectionAttempt >= settings.maxConnectionAttempts) {
      String errorMessage;
      if (settings.uri != null) {
        errorMessage =
            "Could not connect to ${settings.uri} after ${settings.maxConnectionAttempts} attempts. Giving up";
      } else {
        errorMessage =
            "Could not connect to ${settings.host}:${settings.port} after ${settings.maxConnectionAttempts} attempts. Giving up";
      }
      connectionLogger.severe(errorMessage);
      _connected!.completeError(ConnectionFailedException(errorMessage));

      // Clear _connected future so the client can invoke open() in the future
      _connected = null;
    } else {
      // Retry after reconnectWaitTime ms
      Timer(settings.reconnectWaitTime, _reconnect);
    }
  }

  /// Check if a connection is currently in handshake state
  @override
  bool get handshaking =>
      (_socket != null || _webSocketChannel != null) &&
      _connected != null &&
      !_connected!.isCompleted;

  void _handleMessage(DecodedMessage serverMessage) {
    try {
      // If we are still handshaking and we receive a message on another channel this is an error
      if (!_connected!.isCompleted && serverMessage.channel != 0) {
        throw FatalException(
            "Received message for channel ${serverMessage.channel} while still handshaking");
      }

      // Reset heartbeat timer if it has been initialized.
      _heartbeatRecvTimer?.reset();

      // Heartbeat frames should be received on channel 0
      if (serverMessage is HeartbeatFrameImpl) {
        if (serverMessage.channel != 0) {
          throw ConnectionException(
              "Received HEARTBEAT message on a channel > 0",
              ErrorType.COMMAND_INVALID,
              0,
              0);
        }

        // No further processing required.
        return;
      }

      // Connection-class messages should only be received on channel 0
      if (serverMessage.message!.msgClassId == 10 &&
          serverMessage.channel != 0) {
        throw ConnectionException(
            "Received CONNECTION class message on a channel > 0",
            ErrorType.COMMAND_INVALID,
            serverMessage.message!.msgClassId,
            serverMessage.message!.msgMethodId);
      }

      // If we got a ConnectionOpen message from the server and a heartbeat
      // period has been configured, start monitoring incoming heartbeats.
      if (serverMessage.message is ConnectionOpenOk &&
          tuningSettings.heartbeatPeriod.inSeconds > 0) {
        // Raise an exception if we miss maxMissedHeartbeats consecutive
        // heartbeats.
        Duration missInterval =
            tuningSettings.heartbeatPeriod * tuningSettings.maxMissedHeartbeats;
        _heartbeatRecvTimer?.cancel();
        _heartbeatRecvTimer = RestartableTimer(missInterval, () {
          // Set the timer to null to avoid accidentally resetting it while
          // shutting down.
          _heartbeatRecvTimer = null;
          _handleException(HeartbeatFailedException(
              "Server did not respond to heartbeats for ${tuningSettings.heartbeatPeriod.inSeconds}s (missed consecutive heartbeats: ${tuningSettings.maxMissedHeartbeats})"));
        });
      }

      // Fetch target channel and forward frame for processing
      _ChannelImpl? target = _channels[serverMessage.channel];
      if (target == null) {
        // message on unknown channel; ignore
        return;
      }

      // If we got a ConnectionClose message from the server, throw the appropriate exception
      if (serverMessage.message is ConnectionClose) {
        // Ack the closing of the connection
        _channels[0]!.writeMessage(ConnectionCloseOk());

        ConnectionClose serverResponse =
            (serverMessage.message as ConnectionClose);
        throw ConnectionException(
            serverResponse.replyText ?? "Server closed the connection",
            ErrorType.valueOf(serverResponse.replyCode),
            serverResponse.msgClassId,
            serverResponse.msgMethodId);
      }

      // Deliver to channel
      target.handleMessage(serverMessage);

      // If we got a ConnectionCloseOk message before a pending ChannelCloseOk message
      // force the other channels to close
      if (serverMessage.message is ConnectionCloseOk) {
        _channels.values
            .where((_ChannelImpl channel) =>
                channel._channelClosed != null &&
                !channel._channelClosed!.isCompleted)
            .forEach((_ChannelImpl channel) =>
                channel._completeOperation(serverMessage.message));
      }
    } catch (e) {
      _handleException(e);
    }
  }

  void _handleException(ex) {
    // Ignore exceptions while shutting down
    if (_clientClosed != null) {
      return;
    }

    // If we are still handshaking, it could be that the server disconnected us
    // due to a failed SASL auth attempt. In this case we should trigger a connection
    // exception
    if (ex is SocketException) {
      // Wrap the exception
      if (handshaking &&
          _channels.containsKey(0) &&
          (_channels[0]!._lastHandshakeMessage is ConnectionStartOk ||
              _channels[0]!._lastHandshakeMessage is ConnectionSecureOk)) {
        ex = FatalException("Authentication failed");
      } else {
        ex = FatalException("Lost connection to the server");
      }
    }

    connectionLogger.severe(ex);

    // If we are still handshaking, abort the connection; flush the channels and shut down
    if (handshaking) {
      _channels.clear();
      _connected!.completeError(ex);
      _close();
      return;
    }

    if (_error.hasListener && !_error.isClosed) {
      _error.add(ex);
    }

    switch (ex.runtimeType) {
      case HeartbeatFailedException:
      case FatalException:
      case ConnectionException:

        // Forward to all channels and then shutdown
        _channels.values
            .toList()
            .reversed
            .forEach((_ChannelImpl channel) => channel.handleException(ex));

        _close();
        break;
      case ChannelException:
        // Forward to the appropriate channel and remove it from our list
        _ChannelImpl? target = _channels[ex.channel];
        if (target != null) {
          target.handleException(ex);
          _channels.remove(ex.channel);
        }

        break;
    }
  }

  /// Open a working connection to the server using [config.cqlVersion] and optionally select
  /// keyspace [defaultKeyspace]. Returns a [Future] to be completed on a successful protocol handshake

  @override
  Future connect() {
    // Prevent multiple connection attempts
    if (_connected != null) {
      return _connected!.future;
    }

    _connectionAttempt = 0;
    return _reconnect();
  }

  /// Shutdown any open channels and disconnect the socket. Return a [Future] to be completed
  /// when the client has shut down
  @override
  Future close() {
    return _close(closeErrorStream: true);
  }

  Future _close({bool closeErrorStream = false}) {
    _heartbeatRecvTimer?.cancel();
    _heartbeatRecvTimer = null;

    if (_socket == null && _webSocketChannel == null) {
      return Future.value();
    }

    // Already shutting down
    if (_clientClosed != null) {
      return _clientClosed!.future;
    }

    // Close all channels in reverse order so we send a connection close message when we close channel 0
    _clientClosed = Completer();
    Future.wait(_channels.values
            .toList()
            .reversed
            .map((_ChannelImpl channel) => channel.close()))
        .then((_) => _socket?.flush())
        .then((_) {
      _webSocketChannel?.sink.close();
      _socket?.close();
    }, onError: (e) {
      // Mute exception as the socket may be already closed
    }).whenComplete(() {
      _webSocketChannel = null;
      _socket?.destroy();
      _socket = null;
      _connected = null;
      if (closeErrorStream) {
        _error.close();
      }
      _clientClosed!.complete();
      _clientClosed = null;
    });

    return _clientClosed!.future;
  }

  @override
  Future<Channel> channel() {
    return connect().then((_) {
      // Check if we have exceeded our channel limit (open channels excluding channel 0)
      if (tuningSettings.maxChannels > 0 &&
          _channels.length - 1 >= tuningSettings.maxChannels) {
        return Future.error(StateError(
            "Cannot allocate channel; channel limit exceeded (max ${tuningSettings.maxChannels})"));
      }

      // Find next available channel
      _ChannelImpl? userChannel;
      int nextChannelId = 0;
      while (nextChannelId < 65536) {
        if (!_channels.containsKey(++nextChannelId)) {
          // Found empty slot
          userChannel = _ChannelImpl(nextChannelId, this);
          _channels[nextChannelId] = userChannel;
          break;
        }
      }

      // Run out of slots?
      if (userChannel == null) {
        return Future.error(StateError(
            "Cannot allocate channel; all channels are currently in use"));
      }

      return userChannel._channelOpened.future;
    });
  }

  @override
  StreamSubscription<Exception> errorListener(
          void Function(Exception error) onData,
          {Function? onError,
          void Function()? onDone,
          bool cancelOnError = false}) =>
      _error.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  _ChannelImpl _removeChannel(int channelId) => _channels.remove(channelId)!;
}
