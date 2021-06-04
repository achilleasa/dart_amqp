part of dart_amqp.exceptions;

class ChannelException implements Exception {
  final String message;
  final int channel;
  final ErrorType errorType;

  ChannelException(this.message, this.channel, this.errorType);

  @override
  String toString() {
    return "ChannelException(${ErrorType.nameOf(errorType)}): $message";
  }
}
