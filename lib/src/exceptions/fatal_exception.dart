part of dart_amqp.exceptions;

class FatalException implements Exception {
  final String message;

  FatalException(this.message);

  String toString() {
    return "FatalException: ${message}";
  }
}
