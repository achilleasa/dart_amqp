part of dart_amqp.client;

class _ClientImpl implements Client {
  // Configuration options
  ConnectionSettings settings;

  // Tuning settings
  TuningSettings get tuningSettings => settings.tuningSettings;

  // The connection to the server
  int _connectionAttempt;
  Socket _socket;

  // The list of open channels. Channel 0 is always reserved for signaling
  Map<int, _ChannelImpl> _channels = Map<int, _ChannelImpl>();

  // Connection status
  Completer _connected;
  Completer _clientClosed;

  //Error Stream
  final _error = StreamController<Exception>.broadcast();

  _ClientImpl({ConnectionSettings settings}) {
    // Use defaults if no settings specified
    this.settings = settings == null ? ConnectionSettings() : settings;
  }

  /// Attempt to reconnect to the server. If the attempt fails, it will be retried after
  /// [reconnectWaitTime] ms up to [maxConnectionAttempts] times. If all connection attempts
  /// fail, then the [_connected] [Future] returned by a call to [open[ will also fail

  Future _reconnect() {
    _connected ??= Completer();

    Future<Socket> fs;
    if (settings.tlsContext != null) {
      connectionLogger.info(
          "Trying to connect to ${settings.host}:${settings.port} using TLS [attempt ${_connectionAttempt + 1}/${settings.maxConnectionAttempts}]");
      fs = SecureSocket.connect(
        settings.host,
        settings.port,
        context: settings.tlsContext,
      );
    } else {
      connectionLogger.info(
          "Trying to connect to ${settings.host}:${settings.port} [attempt ${_connectionAttempt + 1}/${settings.maxConnectionAttempts}]");
      fs = Socket.connect(settings.host, settings.port);
    }

    fs.then((Socket s) {
      _socket = s;

      // Bind processors and initiate handshake
      RawFrameParser(tuningSettings)
          .transformer
          .bind(_socket)
          .transform(AmqpMessageDecoder().transformer)
          .listen(_handleMessage,
              onError: _handleException,
              onDone: () =>
                  _handleException(const SocketException("Socket closed")));

      // Allocate channel 0 for handshaking and transmit the AMQP header to bootstrap the handshake
      _channels.clear();
      _channels.putIfAbsent(0, () => _ChannelImpl(0, this));
    }).catchError((err, trace) {
      // Connection attempt completed with an error (probably protocol mismatch)
      if (_connected.isCompleted) {
        return;
      }

      if (++_connectionAttempt >= settings.maxConnectionAttempts) {
        String errorMessage =
            "Could not connect to ${settings.host}:${settings.port} after ${settings.maxConnectionAttempts} attempts. Giving up";
        connectionLogger.severe(errorMessage);
        _connected.completeError(ConnectionFailedException(errorMessage));

        // Clear _connected future so the client can invoke open() in the future
        _connected = null;
      } else {
        // Retry after reconnectWaitTime ms
        Timer(settings.reconnectWaitTime, _reconnect);
      }
    });

    return _connected.future;
  }

  /// Check if a connection is currently in handshake state
  bool get handshaking =>
      _socket != null && _connected != null && !_connected.isCompleted;

  void _handleMessage(DecodedMessage serverMessage) {
    try {
      // Heartbeat frames should be received on channel 0
      if (serverMessage is HeartbeatFrameImpl && serverMessage.channel != 0) {
        throw ConnectionException("Received HEARTBEAT message on a channel > 0",
            ErrorType.COMMAND_INVALID, 0, 0);
      }

      // If we are still handshaking and we receive a message on another channel this is an error
      if (!_connected.isCompleted && serverMessage.channel != 0) {
        throw FatalException(
            "Received message for channel ${serverMessage.channel} while still handshaking");
      }

      // Connection-class messages should only be received on channel 0
      if (serverMessage.message.msgClassId == 10 &&
          serverMessage.channel != 0) {
        throw ConnectionException(
            "Received CONNECTION class message on a channel > 0",
            ErrorType.COMMAND_INVALID,
            serverMessage.message.msgClassId,
            serverMessage.message.msgMethodId);
      }

      // Fetch target channel and forward frame for processing
      _ChannelImpl target = _channels[serverMessage.channel];
      if (target == null) {
        // message on unknown channel; ignore
        return;
      }

      // If we got a ConnectionClose message from the server, throw the appropriate exception
      if (serverMessage.message is ConnectionClose) {
        // Ack the closing of the connection
        _channels[0].writeMessage(ConnectionCloseOk());

        ConnectionClose serverResponse =
            (serverMessage.message as ConnectionClose);
        throw ConnectionException(
            serverResponse.replyText,
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
                !channel._channelClosed.isCompleted)
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
          (_channels[0]._lastHandshakeMessage is ConnectionStartOk ||
              _channels[0]._lastHandshakeMessage is ConnectionSecureOk)) {
        ex = FatalException("Authentication failed");
      } else {
        ex = FatalException("Lost connection to the server");
      }
    }

    connectionLogger.severe(ex);

    // If we are still handshaking, abort the connection; flush the channels and shut down
    if (handshaking) {
      _channels.clear();
      _connected.completeError(ex);
      close();
      return;
    }

    if (_error != null && _error.hasListener && !_error.isClosed) {
      _error.add(ex);
    }

    switch (ex.runtimeType) {
      case FatalException:
      case ConnectionException:

        // Forward to all channels and then shutdown
        _channels.values
            .toList()
            .reversed
            .forEach((_ChannelImpl channel) => channel.handleException(ex));

        close();
        break;
      case ChannelException:
        // Forward to the appropriate channel and remove it from our list
        _ChannelImpl target = _channels[ex.channel];
        if (target != null) {
          target.handleException(ex);
          _channels.remove(ex.channel);
        }

        break;
    }
  }

  /// Open a working connection to the server using [config.cqlVersion] and optionally select
  /// keyspace [defaultKeyspace]. Returns a [Future] to be completed on a successful protocol handshake

  Future connect() {
    // Prevent multiple connection attempts
    if (_connected != null) {
      return _connected.future;
    }

    _connectionAttempt = 0;
    return _reconnect();
  }

  /// Shutdown any open channels and disconnect the socket. Return a [Future] to be completed
  /// when the client has shut down
  Future close() {
    if (_socket == null) {
      return Future.value();
    }

    // Already shutting down
    if (_clientClosed != null) {
      return _clientClosed.future;
    }

    // Close all channels in reverse order so we send a connection close message when we close channel 0
    _clientClosed = Completer();
    Future.wait(_channels.values
            .toList()
            .reversed
            .map((_ChannelImpl channel) => channel.close()))
        .then((_) => _socket.flush())
        .then((_) => _socket.close(), onError: (e) {
      // Mute exception as the socket may be already closed
    }).whenComplete(() {
      _socket.destroy();
      _socket = null;
      _connected = null;
      _error.close();
      _clientClosed.complete();
    });

    return _clientClosed.future;
  }

  Future<Channel> channel() {
    return connect().then((_) {
      // Check if we have exceeded our channel limit (open channels excluding channel 0)
      if (tuningSettings.maxChannels > 0 &&
          _channels.length - 1 >= tuningSettings.maxChannels) {
        return Future.error(StateError(
            "Cannot allocate channel; channel limit exceeded (max ${tuningSettings.maxChannels})"));
      }

      // Find next available channel
      _ChannelImpl userChannel;
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

  StreamSubscription<Exception> errorListener(void onData(Exception error),
          {Function onError, void onDone(), bool cancelOnError}) =>
      _error.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  _ChannelImpl _removeChannel(int channelId) => _channels.remove(channelId);
}
