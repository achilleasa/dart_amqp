part of dart_amqp.protocol;

final Uint8List FRAME_TERMINATOR_SEQUENCE =
    Uint8List.fromList([RawFrameParser.FRAME_TERMINATOR]);

class FrameWriter {
  final FrameHeader _frameHeader;
  final ContentHeader _contentHeader;
  final TypeEncoder _bufferEncoder;
  final TypeEncoder _outputEncoder;

  final TuningSettings _tuningSettings;

  FrameWriter(this._tuningSettings)
      : _frameHeader = FrameHeader(),
        _contentHeader = ContentHeader(),
        _bufferEncoder = TypeEncoder(),
        _outputEncoder = TypeEncoder();

  void writeMessage(int channelId, Message message,
      {MessageProperties properties, Object payloadContent}) {
    // Make sure our buffer contains no stale data from previous messages
    _outputEncoder.writer.clear();

    // Buffer message so we can measure its length
    message.serialize(_outputEncoder);

    // Now that we know the message length, create the header and prepend it to the encoder
    _frameHeader
      ..channel = channelId
      ..type = FrameType.METHOD
      ..size = _outputEncoder.writer.lengthInBytes
      ..serialize(_bufferEncoder);

    _outputEncoder.writer
      ..addFirst(_bufferEncoder.writer.joinChunks())
      ..addLast(FRAME_TERMINATOR_SEQUENCE);

    _bufferEncoder.writer.clear();

    // if a data payload is specified, encode it and append it before flushing the buffer
    if (payloadContent != null) {
      // Serialize content
      Uint8List serializedContent;
      if (payloadContent is Uint8List) {
        serializedContent = payloadContent;
      } else if (payloadContent is Map || payloadContent is Iterable) {
        serializedContent =
            Uint8List.fromList(utf8.encode(json.encode(payloadContent)));
        properties = (properties == null ? MessageProperties() : properties)
          ..contentType = "application/json"
          ..contentEncoding = "UTF-8";
      } else if (payloadContent is String) {
        serializedContent = Uint8List.fromList(utf8.encode(payloadContent));
      } else {
        throw ArgumentError(
            "Message payload should be either a Map, an Iterable, a String or an UInt8List instance");
      }

      // Build the content header
      _contentHeader
        ..classId = message.msgClassId
        ..bodySize = serializedContent.lengthInBytes
        ..properties = properties
        ..serialize(_bufferEncoder);

      Uint8List serializedContentHeader = _bufferEncoder.writer.joinChunks();
      _contentHeader.properties = null;
      _bufferEncoder.writer.clear();

      // Fill in the frame header for the content header frame
      _frameHeader
        ..type = FrameType.HEADER
        ..size = serializedContentHeader.lengthInBytes
        ..serialize(_bufferEncoder);

      // Append after the method frame
      _outputEncoder.writer
        ..addLast(_bufferEncoder.writer.joinChunks())
        ..addLast(serializedContentHeader)
        ..addLast(FRAME_TERMINATOR_SEQUENCE);
      _bufferEncoder.writer.clear();

      // Emit the payload data split in ceil( length / maxFrameLength ) chunks
      int contentLen = serializedContent.lengthInBytes;
      for (int offset = 0;
          offset < contentLen;
          offset += _tuningSettings.maxFrameSize) {
        // Setup  and encode the frame header
        _frameHeader
          ..type = FrameType.BODY
          ..size = math.min(_tuningSettings.maxFrameSize, contentLen - offset)
          ..serialize(_outputEncoder);

        // Encode the payload for the frame
        _outputEncoder.writer
          ..addLast(Uint8List.view(
              serializedContent.buffer, offset, _frameHeader.size))
          ..addLast(FRAME_TERMINATOR_SEQUENCE);
      }
    }
  }

  void writeProtocolHeader(
      int protocolVersion, int majorVersion, int minorVersion, int revision) {
    ProtocolHeader()
      ..protocolVersion = protocolVersion
      ..majorVersion = majorVersion
      ..minorVersion = minorVersion
      ..revision = revision
      ..serialize(_outputEncoder);
  }

  void writeHeartbeat() {
    _outputEncoder.writer.addLast(Uint8List.fromList(
        [8, 0, 0, 0, 0, 0, 0, RawFrameParser.FRAME_TERMINATOR]));
  }

  /// Pipe encoded frame data to [sink]
  void pipe(Sink sink) {
    _outputEncoder.writer.pipe(sink);
  }

  TypeEncoder get outputEncoder => _outputEncoder;
}
