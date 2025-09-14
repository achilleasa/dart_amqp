part of "../../client.dart";

class _ClientStompImpl implements Client {
  // Configuration options
  @override
  late ConnectionSettings settings;

  // Tuning settings
  @override
  TuningSettings get tuningSettings => settings.tuningSettings;

  // STOMP client instance
  StompClient? _stompClient;

  // The list of open channels. Channel 0 is always reserved for signaling
  final Map<int, _ChannelStompImpl> _channels = <int, _ChannelStompImpl>{};

  // Connection status
  Completer? _connected;
  Completer? _clientClosed;
  bool _isConnected = false;

  // Error Stream
  final _error = StreamController<Exception>.broadcast();

  _ClientStompImpl({ConnectionSettings? settings}) {
    // Use defaults if no settings specified
    this.settings = settings ?? ConnectionSettings();
  }

  /// Check if a connection is currently in handshake state
  @override
  bool get handshaking => _stompClient != null && !_isConnected;

  /// Check if client is connected and ready
  bool get isConnected => _isConnected && _stompClient != null && _stompClient!.isActive;

  @override
  Future connect() {
    // Prevent multiple connection attempts
    if (_connected != null) {
      return _connected!.future;
    }

    _connected = Completer();

    try {
      // Real STOMP client implementation
      final String wsScheme = (settings.port == 443) ? 'wss' : 'ws';
      _stompClient = StompClient(
        config: StompConfig(
          url: '$wsScheme://${settings.host}:${settings.port}/ws',
          onConnect: _onStompConnect,
          onDisconnect: _onStompDisconnect,
          onStompError: _onStompError,
          onWebSocketError: _onWebSocketError,
          stompConnectHeaders: {
            'login': settings.authProvider is PlainAuthenticator ? (settings.authProvider as PlainAuthenticator).userName : 'guest',
            'passcode': settings.authProvider is PlainAuthenticator ? (settings.authProvider as PlainAuthenticator).password : 'guest',
            'host': '/',
            if (settings.connectionName != null) 'client-id': settings.connectionName! else 'client-id': 'dart_amqp_client_${DateTime.now().millisecondsSinceEpoch}'
          },
          heartbeatOutgoing: const Duration(seconds: 10),
          heartbeatIncoming: const Duration(seconds: 10),
          // FIX: Web-specific configurations to avoid type error
          webSocketConnectHeaders: const {},
          reconnectDelay: const Duration(seconds: 5),
        ),
      );

      connectionLogger.info('Attempting to connect to STOMP server at ${settings.host}:${settings.port}');
      _stompClient!.activate();
    } catch (e) {
      _connected!.completeError(ConnectionFailedException("Failed to connect to STOMP server: $e"));
      _connected = null;
    }

    return _connected!.future;
  }

  void _onStompConnect(StompFrame frame) {
    connectionLogger.info('Connected to STOMP server');
    _isConnected = true;

    // Allocate channel 0 for signaling
    _channels.clear();
    _channels.putIfAbsent(0, () => _ChannelStompImpl(0, this));

    if (!_connected!.isCompleted) {
      _connected!.complete();
    }
  }

  void _onStompError(StompFrame frame) {
    connectionLogger.severe('STOMP error: ${frame.body}');
    _handleException(FatalException("STOMP error: ${frame.body}"));
  }

  void _onStompDisconnect(StompFrame frame) {
    connectionLogger.info('Disconnected from STOMP server');
    _isConnected = false;
    if (_connected != null && !_connected!.isCompleted) {
      _connected!.completeError(ConnectionFailedException("STOMP connection lost"));
    }
  }

  void _onWebSocketError(dynamic error) {
    connectionLogger.severe('WebSocket error: $error');
    _handleException(FatalException("WebSocket error: $error"));
  }

  void _handleException(Exception ex) {
    // Ignore exceptions while shutting down
    if (_clientClosed != null) {
      return;
    }

    connectionLogger.severe(ex);

    // If we are still handshaking, abort the connection
    if (handshaking) {
      _channels.clear();
      if (!_connected!.isCompleted) {
        _connected!.completeError(ex);
      }
      _close();
      return;
    }

    if (_error.hasListener && !_error.isClosed) {
      _error.add(ex);
    }

    // Forward to all channels and then shutdown for fatal exceptions
    if (ex is FatalException) {
      _channels.values.toList().reversed.forEach((_ChannelStompImpl channel) => channel.handleException(ex));
      _close();
    }
  }

  @override
  Future close() {
    return _close(closeErrorStream: true);
  }

  Future _close({bool closeErrorStream = false}) {
    if (_stompClient == null) {
      return Future.value();
    }

    // Already shutting down
    if (_clientClosed != null) {
      return _clientClosed!.future;
    }

    _clientClosed = Completer();

    try {
      if (_isConnected) {
        _stompClient?.deactivate();
      }
    } catch (e) {
      connectionLogger.warning('Error deactivating STOMP client: $e');
    }

    // Close all channels
    Future.wait(_channels.values.toList().reversed.map((_ChannelStompImpl channel) => channel.close())).whenComplete(() {
      _stompClient = null;
      _connected = null;
      _isConnected = false;
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
      if (tuningSettings.maxChannels > 0 && _channels.length - 1 >= tuningSettings.maxChannels) {
        return Future.error(StateError("Cannot allocate channel; channel limit exceeded (max ${tuningSettings.maxChannels})"));
      }

      // Find next available channel
      _ChannelStompImpl? userChannel;
      int nextChannelId = 0;
      while (nextChannelId < 65536) {
        if (!_channels.containsKey(++nextChannelId)) {
          // Found empty slot
          userChannel = _ChannelStompImpl(nextChannelId, this);
          _channels[nextChannelId] = userChannel;
          break;
        }
      }

      // Run out of slots?
      if (userChannel == null) {
        return Future.error(StateError("Cannot allocate channel; all channels are currently in use"));
      }

      return userChannel._channelOpened.future;
    });
  }

  @override
  StreamSubscription<Exception> errorListener(void Function(Exception error) onData, {Function? onError, void Function()? onDone, bool cancelOnError = false}) => _error.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  // Getter to access the STOMP client (used by channels)
  StompClient? get stompClient => _stompClient;
}
