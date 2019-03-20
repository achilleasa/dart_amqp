part of dart_amqp.exceptions;

class QueueNotFoundException extends ChannelException {
  QueueNotFoundException(String message, int channel, ErrorType errorType)
      : super(message, channel, errorType);

  String toString() {
    return "QueueNotFoundException: ${message}";
  }
}
