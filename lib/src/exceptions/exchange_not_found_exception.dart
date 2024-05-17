part of "../exceptions.dart";

class ExchangeNotFoundException extends ChannelException {
  ExchangeNotFoundException(String message, int channel, ErrorType errorType)
      : super(message, channel, errorType);

  @override
  String toString() {
    return "ExchangeNotFoundException: $message";
  }
}
