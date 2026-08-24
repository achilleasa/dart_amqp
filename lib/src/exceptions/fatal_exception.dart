part of "../exceptions.dart";

class FatalException implements Exception {
  final String message;
  final Object? sourceError;
  final StackTrace? sourceStackTrace;

  FatalException(this.message, {this.sourceError, this.sourceStackTrace});

  @override
  String toString() {
    return "FatalException: $message";
  }
}
