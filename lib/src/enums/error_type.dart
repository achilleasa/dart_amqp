part of dart_amqp.enums;

class ErrorType extends Enum<int> {

  static const ErrorType SUCCESS = const ErrorType._(200, false);
  static const ErrorType CONTENT_TOO_LARGE = const ErrorType._(311, false);
  static const ErrorType NO_CONSUMERS = const ErrorType._(313, false);
  static const ErrorType CONNECTION_FORCED = const ErrorType._(320, true);
  static const ErrorType INVALID_PATH = const ErrorType._(402, true);
  static const ErrorType ACCESS_REFUSED = const ErrorType._(403, false);
  static const ErrorType NOT_FOUND = const ErrorType._(404, false);
  static const ErrorType RESOURCE_LOCKED = const ErrorType._(405, false);
  static const ErrorType PRECONDITION_FAILED = const ErrorType._(406, false);
  static const ErrorType FRAME_ERROR = const ErrorType._(501, true);
  static const ErrorType SYNTAX_ERROR = const ErrorType._(502, true);
  static const ErrorType COMMAND_INVALID = const ErrorType._(503, true);
  static const ErrorType CHANNEL_ERROR = const ErrorType._(504, true);
  static const ErrorType UNEXPECTED_FRAME = const ErrorType._(505, true);
  static const ErrorType RESOURCE_ERROR = const ErrorType._(506, true);
  static const ErrorType NOT_ALLOWED = const ErrorType._(530, true);
  static const ErrorType NOT_IMPLEMENTED = const ErrorType._(540, true);
  static const ErrorType INTERNAL_ERROR = const ErrorType._(541, true);

  final bool isHardError;

  const ErrorType._(int value, bool hardError) : super(value), isHardError = hardError;

  String toString() => "${value}";

  static ErrorType valueOf(int value) {
    ErrorType fromValue = value == SUCCESS._value ? SUCCESS :
                          value == CONTENT_TOO_LARGE._value ? CONTENT_TOO_LARGE :
                          value == NO_CONSUMERS._value ? NO_CONSUMERS :
                          value == CONNECTION_FORCED._value ? CONNECTION_FORCED :
                          value == INVALID_PATH._value ? INVALID_PATH :
                          value == ACCESS_REFUSED._value ? ACCESS_REFUSED :
                          value == NOT_FOUND._value ? NOT_FOUND :
                          value == RESOURCE_LOCKED._value ? RESOURCE_LOCKED :
                          value == PRECONDITION_FAILED._value ? PRECONDITION_FAILED :
                          value == FRAME_ERROR._value ? FRAME_ERROR :
                          value == SYNTAX_ERROR._value ? SYNTAX_ERROR :
                          value == COMMAND_INVALID._value ? COMMAND_INVALID :
                          value == CHANNEL_ERROR._value ? CHANNEL_ERROR :
                          value == UNEXPECTED_FRAME._value ? UNEXPECTED_FRAME :
                          value == RESOURCE_ERROR._value ? RESOURCE_ERROR :
                          value == NOT_ALLOWED._value ? NOT_ALLOWED :
                          value == NOT_IMPLEMENTED._value ? NOT_IMPLEMENTED :
                          value == INTERNAL_ERROR._value ? INTERNAL_ERROR : null;

    if (fromValue == null) {
      throw new ArgumentError("Invalid error type value ${value}");
    }
    return fromValue;
  }

  static String nameOf(ErrorType value) {
    String name = value == SUCCESS ? "SUCCESS" :
                  value == CONTENT_TOO_LARGE ? "CONTENT_TOO_LARGE" :
                  value == NO_CONSUMERS ? "NO_CONSUMERS" :
                  value == CONNECTION_FORCED ? "CONNECTION_FORCED" :
                  value == INVALID_PATH ? "INVALID_PATH" :
                  value == ACCESS_REFUSED ? "ACCESS_REFUSED" :
                  value == NOT_FOUND ? "NOT_FOUND" :
                  value == RESOURCE_LOCKED ? "RESOURCE_LOCKED" :
                  value == PRECONDITION_FAILED ? "PRECONDITION_FAILED" :
                  value == FRAME_ERROR ? "FRAME_ERROR" :
                  value == SYNTAX_ERROR ? "SYNTAX_ERROR" :
                  value == COMMAND_INVALID ? "COMMAND_INVALID" :
                  value == CHANNEL_ERROR ? "CHANNEL_ERROR" :
                  value == UNEXPECTED_FRAME ? "UNEXPECTED_FRAME" :
                  value == RESOURCE_ERROR ? "RESOURCE_ERROR" :
                  value == NOT_ALLOWED ? "NOT_ALLOWED" :
                  value == NOT_IMPLEMENTED ? "NOT_IMPLEMENTED" :
                  value == INTERNAL_ERROR ? "INTERNAL_ERROR" : null;

    return name;
  }
}

