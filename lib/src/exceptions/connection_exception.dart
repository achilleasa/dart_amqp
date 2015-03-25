part of dart_amqp.exceptions;

class ConnectionException implements Exception {
  final String message;
  final ErrorType errorType;
  final int classId;
  final int methodId;

  ConnectionException(String this.message, ErrorType this.errorType, int this.classId, int this.methodId);

  String toString() {
    return "ConnectionException(${ErrorType.nameOf(errorType)}): ${message}";
  }
}
