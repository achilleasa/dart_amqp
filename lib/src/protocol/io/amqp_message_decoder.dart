part of dart_amqp.protocol;

class AmqpMessageDecoder {
  Map<int, DecodedMessageImpl> incompleteMessages =
      Map<int, DecodedMessageImpl>();

  StreamTransformer<RawFrame, DecodedMessage> get transformer =>
      StreamTransformer<RawFrame, DecodedMessage>.fromHandlers(
          handleData: handleData,
          handleDone: handleDone,
          handleError: handleError);

  void handleError(
      Object error, StackTrace stackTrace, EventSink<DecodedMessage> sink) {
    sink.addError(error, stackTrace);
  }

  void handleDone(EventSink<DecodedMessage> sink) {
    sink.close();
  }

  void handleData(RawFrame rawFrame, EventSink<DecodedMessage> sink) {
    TypeDecoder decoder = TypeDecoder.fromBuffer(rawFrame.payload);

    switch (rawFrame.header.type) {
      case FrameType.METHOD:
        DecodedMessageImpl decodedMessage = DecodedMessageImpl(
            rawFrame.header.channel, Message.fromStream(decoder));
        // If we are already processing an incomplete frame then this is an error
        if (incompleteMessages.containsKey(decodedMessage.channel)) {
          throw ConnectionException(
              "Received a new METHOD frame while processing an incomplete METHOD frame",
              ErrorType.UNEXPECTED_FRAME,
              decodedMessage.message.msgClassId,
              decodedMessage.message.msgMethodId);
        }

        // If this message defines content add it to the incomplete frame buffer
        if (decodedMessage.message.msgHasContent) {
          incompleteMessages[decodedMessage.channel] = decodedMessage;
        } else {
          // Frame is complete; emit it
          sink.add(decodedMessage);
        }
        break;
      case FrameType.HEADER:
        // Read the content header
        ContentHeader contentHeader = ContentHeader.fromByteData(decoder);

        DecodedMessageImpl decodedMessage =
            incompleteMessages[rawFrame.header.channel];

        // Check for errors
        if (decodedMessage == null) {
          throw ConnectionException(
              "Received a HEADER frame without a matching METHOD frame",
              ErrorType.UNEXPECTED_FRAME,
              contentHeader.classId,
              0);
        } else if (decodedMessage.contentHeader != null) {
          throw ConnectionException(
              "Received a duplicate HEADER frame for an incomplete METHOD frame",
              ErrorType.UNEXPECTED_FRAME,
              contentHeader.classId,
              0);
        } else if (decodedMessage.message.msgClassId != contentHeader.classId) {
          throw ConnectionException(
              "Received a HEADER frame that does not match the METHOD frame class id",
              ErrorType.UNEXPECTED_FRAME,
              contentHeader.classId,
              0);
        }

        // Store the content header and set the message properties to point to the parsed header properties
        decodedMessage..contentHeader = contentHeader;

        // If the frame defines no content emit it now
        if (decodedMessage.contentHeader.bodySize == 0) {
          sink.add(incompleteMessages.remove(decodedMessage.channel));
        } else {
          decodedMessage.payloadBuffer = ChunkedOutputWriter();
        }
        break;
      case FrameType.BODY:
        DecodedMessageImpl decodedMessage =
            incompleteMessages[rawFrame.header.channel];

        // Check for errors
        if (decodedMessage == null) {
          throw ConnectionException(
              "Received a BODY frame without a matching METHOD frame",
              ErrorType.UNEXPECTED_FRAME,
              0,
              0);
        } else if (decodedMessage.contentHeader == null) {
          throw ConnectionException(
              "Received a BODY frame before a HEADER frame",
              ErrorType.UNEXPECTED_FRAME,
              decodedMessage.message.msgClassId,
              decodedMessage.message.msgMethodId);
        }

        // Append the payload chunk
        decodedMessage.payloadBuffer.addLast(Uint8List.view(
            rawFrame.payload.buffer, 0, rawFrame.payload.lengthInBytes));

        // Are we done?
        if (decodedMessage.payloadBuffer.lengthInBytes ==
            decodedMessage.contentHeader.bodySize) {
          decodedMessage.finalizePayload();
          sink.add(incompleteMessages.remove(decodedMessage.channel));
        }
        break;
      case FrameType.HEARTBEAT:
        sink.add(HeartbeatFrameImpl(rawFrame.header.channel));
        break;
    }
  }
}
