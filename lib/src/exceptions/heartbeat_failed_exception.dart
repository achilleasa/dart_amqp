part of dart_amqp.exceptions;

class HeartbeatFailedException implements Exception {
  final String message;

  HeartbeatFailedException(this.message);

  @override
  String toString() {
    return message;
  }
}
