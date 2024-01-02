part of dart_amqp.tests.mocks;

class MockServer {
  ServerSocket? _server;
  List<Socket> clients = [];
  List replayList = [];
  Duration responseDelay = const Duration(seconds: 0);

  MockServer();

  Future shutdown() {
    replayList = [];

    if (_server != null) {
      mockLogger
          .info("Shutting down server [${_server!.address}:${_server!.port}]");

      List<Future> cleanupFutures = [
        ...clients.map((Socket client) async {
          client.destroy();
          return true;
        }),
        _server!.close().then((_) =>
            Future.delayed(const Duration(milliseconds: 20), () => true)),
      ];

      clients.clear();
      _server = null;

      return Future.wait(cleanupFutures);
    }

    return Future.value();
  }

  void disconnectClient(int clientIndex) {
    if (clients.length > clientIndex) {
      Socket client = clients.removeAt(clientIndex);
      mockLogger.info(
          "Disconnecting client [${client.remoteAddress.host}:${client.remotePort}]");
      client.destroy();
    }
  }

  Future listen(String host, int port) async {
    mockLogger.info("Binding MockServer to $host:$port");

    _server = await ServerSocket.bind(host, port, shared: true);
    mockLogger.info("[$host:$port] Listening for incoming connections");
    _server!.listen(_handleConnection);
  }

  void _handleConnection(Socket client) {
    clients.add(client);
    mockLogger.info(
        "Client [${client.remoteAddress.host}:${client.remotePort}] connected");

    client.listen((data) => _handleClientData(client, data),
        onError: (err, trace) => _handleClientError(client, err, trace));
  }

  void _handleClientData(Socket client, dynamic data) {
    if (replayList.isNotEmpty) {
      // Respond with the next payload in replay list
      Future.delayed(responseDelay).then((_) {
        client
          ..add(replayList.removeAt(0))
          ..flush();
      });
    }
  }

  void _handleClientError(Socket client, err, trace) {
    mockLogger.info(
        "Client [${client.remoteAddress.host}:${client.remotePort}] error ${err.exception.message}");
    mockLogger.info("${err.stackTrace}");
  }

  void generateHandshakeMessages(
    FrameWriter frameWriter, {
    int numChapRounds = 0,
    Duration heartbeatPeriod = Duration.zero,
  }) {
    // Connection start
    frameWriter.writeMessage(
        0,
        ConnectionStartMock()
          ..versionMajor = 0
          ..versionMinor = 9
          ..serverProperties = {"product": "foo"}
          ..mechanisms = "PLAIN"
          ..locales = "en");
    replayList.add(frameWriter.outputEncoder.writer.joinChunks());
    frameWriter.outputEncoder.writer.clear();

    // Challenge - response rounds
    for (int round = 0; round < numChapRounds; round++) {
      // Connection secure
      frameWriter.writeMessage(
          0, ConnectionSecureMock()..challenge = "round$round");
      replayList.add(frameWriter.outputEncoder.writer.joinChunks());
      frameWriter.outputEncoder.writer.clear();
    }

    // Connection tune
    frameWriter.writeMessage(
        0,
        ConnectionTuneMock()
          ..channelMax = 0
          ..frameMax = (TuningSettings()).maxFrameSize
          ..heartbeat = heartbeatPeriod.inSeconds);
    replayList.add(frameWriter.outputEncoder.writer.joinChunks());
    frameWriter.outputEncoder.writer.clear();

    // Connection open ok
    frameWriter.writeMessage(0, ConnectionOpenOkMock());
    replayList.add(frameWriter.outputEncoder.writer.joinChunks());
    frameWriter.outputEncoder.writer.clear();
  }
}

class _RotEncoder extends Converter<Map, Uint8List> {
  final bool throwOnConvert;
  final int _key;

  const _RotEncoder(this._key, this.throwOnConvert);

  @override
  Uint8List convert(Map input) {
    if (throwOnConvert) {
      throw Exception("Something has gone awfully wrong...");
    }
    String serializedMap = json.encode(input);
    Uint8List result = Uint8List(serializedMap.length);

    for (int i = 0; i < serializedMap.length; i++) {
      result[i] = (serializedMap.codeUnitAt(i) + _key) % 256;
    }

    return result;
  }
}

class _RotDecoder extends Converter<Uint8List, Map> {
  final bool throwOnConvert;
  final int _key;

  const _RotDecoder(this._key, this.throwOnConvert);

  @override
  Map convert(Uint8List input) {
    if (throwOnConvert) {
      throw Exception("Something has gone awfully wrong...");
    }
    Uint8List result = Uint8List(input.length);

    for (int i = 0; i < input.length; i++) {
      result[i] = (input[i] + _key) % 256;
    }

    return json.decode(String.fromCharCodes(result));
  }
}

class RotCodec extends Codec<Map, Uint8List> {
  bool throwOnEncode;
  bool throwOnDecode;

  // For our test apply ROT-13 to compress/decompress
  late _RotEncoder _encoder;
  late _RotDecoder _decoder;

  RotCodec({this.throwOnEncode = false, this.throwOnDecode = false}) {
    _encoder = _RotEncoder(13, throwOnEncode);
    _decoder = _RotDecoder(-13, throwOnDecode);
  }

  @override
  Converter<Map, Uint8List> get encoder {
    return _encoder;
  }

  @override
  Converter<Uint8List, Map> get decoder {
    return _decoder;
  }
}
