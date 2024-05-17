part of "../exceptions.dart";

class FatalException implements Exception {
  final String message;

  FatalException(this.message);

  @override
  String toString() {
    return "FatalException: $message";
  }
}
