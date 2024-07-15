part of "../../protocol.dart";

class RawFrameParser {
  static const int FRAME_TERMINATOR = 0xCE;
  TuningSettings tuningSettings;

  final ChunkedInputReader _inputBuffer = ChunkedInputReader();
  FrameHeader? _parsedHeader;
  Uint8List? _bodyData;
  int _bodyWriteOffset = 0;

  RawFrameParser(this.tuningSettings);

  void handleData(dynamic chunk, EventSink<RawFrame> sink) {
    try {
      // Append incoming chunk to input buffer
      if (chunk != null) {
        _inputBuffer.add(chunk);
      }

      // Process frames till we exhaust our input buffer
      while (_inputBuffer.length > 0) {
        // Are we extracting header bytes?
        if (_parsedHeader == null) {
          // Not enough bytes to parse header; wait till we get more
          if (_inputBuffer.length < FrameHeader.LENGTH_IN_BYTES) {
            return;
          }

          // Peek the first value in the stream. If it is character 'A' (char code 65) then the server
          // rejected our protocol header and responded with the one it supports
          if (_inputBuffer.peekNextByte() == 65) {
            // Make sure we can parse the entire header
            if (_inputBuffer.length < ProtocolHeader.LENGTH_IN_BYTES) {
              return;
            }

            Uint8List headerBytes = Uint8List(ProtocolHeader.LENGTH_IN_BYTES);
            _inputBuffer.read(headerBytes, ProtocolHeader.LENGTH_IN_BYTES);
            ProtocolHeader protocolHeader = ProtocolHeader.fromByteData(
                TypeDecoder.fromBuffer(ByteData.view(headerBytes.buffer)));
            throw FatalException(
                "Could not negotiate a valid AMQP protocol version. Server supports AMQP ${protocolHeader.majorVersion}.${protocolHeader.minorVersion}.${protocolHeader.revision}");
          }

          // Extract header bytes and parse them
          Uint8List? headerBytes = Uint8List(FrameHeader.LENGTH_IN_BYTES);
          _inputBuffer.read(headerBytes, FrameHeader.LENGTH_IN_BYTES);
          _parsedHeader = FrameHeader.fromByteData(
              TypeDecoder.fromBuffer(ByteData.view(headerBytes.buffer)));
          headerBytes = null;

          if (_parsedHeader!.size > tuningSettings.maxFrameSize) {
            throw ConnectionException(
                "Frame size cannot be larger than ${tuningSettings.maxFrameSize} bytes. Server sent ${_parsedHeader!.size} bytes",
                ErrorType.FRAME_ERROR,
                0,
                0);
          }

          // Allocate buffer for body (and frame terminator); then reset write offset
          _bodyData = Uint8List(_parsedHeader!.size + 1);
          _bodyWriteOffset = 0;
        } else {
          // Copy pending body data + expected frame terminator (0xCE)
          _bodyWriteOffset += _inputBuffer.read(_bodyData!,
              _parsedHeader!.size + 1 - _bodyWriteOffset, _bodyWriteOffset);
        }

        // If we are done emit the frame to the next pipeline stage and cleanup
        if (_bodyWriteOffset == _parsedHeader!.size + 1) {
          // Ensure that the last byte of the payload is our frame terminator
          if (_bodyData!.last != FRAME_TERMINATOR) {
            throw FatalException(
                "Frame did not end with the expected frame terminator (0xCE)");
          }

          // Emit a raw frame excluding the frame terminator
          sink.add(RawFrame(
              _parsedHeader!,
              ByteData.view(
                  _bodyData!.buffer, 0, _bodyData!.lengthInBytes - 1)));

          _parsedHeader = null;
          _bodyData = null;
        }
      }
    } catch (ex) {
      _parsedHeader = null;
      _bodyData = null;

      sink.addError(ex);
    }
  }

  void handleDone(EventSink<RawFrame> sink) {
    sink.close();
  }

  void handleError(
      Object error, StackTrace stackTrace, EventSink<RawFrame> sink) {
    sink.addError(error, stackTrace);
  }

  StreamTransformer<dynamic, RawFrame> get transformer =>
      StreamTransformer<dynamic, RawFrame>.fromHandlers(
          handleData: handleData,
          handleDone: handleDone,
          handleError: handleError);
}
