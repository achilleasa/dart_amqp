part of "../exceptions.dart";

class QueueNotFoundException extends ChannelException {
  QueueNotFoundException(String message, int channel, ErrorType errorType)
      : super(message, channel, errorType);

  @override
  String toString() {
    return "QueueNotFoundException: $message";
  }
}
