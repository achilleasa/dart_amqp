part of dart_amqp.exceptions;

class ConnectionException implements Exception {
  final String message;
  final ErrorType errorType;
  final int classId;
  final int methodId;

  ConnectionException(
    this.message,
    this.errorType,
    this.classId,
    this.methodId,
  );

  String toString() {
    return "ConnectionException(${ErrorType.nameOf(errorType)}): ${message}";
  }
}
