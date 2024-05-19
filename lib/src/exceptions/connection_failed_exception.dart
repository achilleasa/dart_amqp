part of "../exceptions.dart";

class ConnectionFailedException implements Exception {
  final String message;

  ConnectionFailedException(this.message);

  @override
  String toString() {
    return "ConnectionFailedException: $message";
  }
}
