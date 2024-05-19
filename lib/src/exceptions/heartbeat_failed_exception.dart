part of "../exceptions.dart";

class HeartbeatFailedException implements Exception {
  final String message;

  HeartbeatFailedException(this.message);

  @override
  String toString() {
    return message;
  }
}
