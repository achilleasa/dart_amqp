part of dart_amqp.exceptions;

class ChannelException implements Exception {
  final String message;
  final int channel;
  final ErrorType errorType;

  ChannelException(
      String this.message, int this.channel, ErrorType this.errorType);

  String toString() {
    return "ChannelException(${ErrorType.nameOf(errorType)}): ${message}";
  }
}
