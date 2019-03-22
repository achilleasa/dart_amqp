part of dart_amqp.enums;

class ErrorType extends Enum<int> {
  static const ErrorType SUCCESS = ErrorType._(200, false);
  static const ErrorType CONTENT_TOO_LARGE = ErrorType._(311, false);
  static const ErrorType NO_CONSUMERS = ErrorType._(313, false);
  static const ErrorType CONNECTION_FORCED = ErrorType._(320, true);
  static const ErrorType INVALID_PATH = ErrorType._(402, true);
  static const ErrorType ACCESS_REFUSED = ErrorType._(403, false);
  static const ErrorType NOT_FOUND = ErrorType._(404, false);
  static const ErrorType RESOURCE_LOCKED = ErrorType._(405, false);
  static const ErrorType PRECONDITION_FAILED = ErrorType._(406, false);
  static const ErrorType FRAME_ERROR = ErrorType._(501, true);
  static const ErrorType SYNTAX_ERROR = ErrorType._(502, true);
  static const ErrorType COMMAND_INVALID = ErrorType._(503, true);
  static const ErrorType CHANNEL_ERROR = ErrorType._(504, true);
  static const ErrorType UNEXPECTED_FRAME = ErrorType._(505, true);
  static const ErrorType RESOURCE_ERROR = ErrorType._(506, true);
  static const ErrorType NOT_ALLOWED = ErrorType._(530, true);
  static const ErrorType NOT_IMPLEMENTED = ErrorType._(540, true);
  static const ErrorType INTERNAL_ERROR = ErrorType._(541, true);

  final bool isHardError;

  const ErrorType._(int value, bool hardError)
      : isHardError = hardError,
        super(value);

  String toString() => "${value}";

  static ErrorType valueOf(int value) {
    if (value == SUCCESS.value) return SUCCESS;
    if (value == CONTENT_TOO_LARGE.value) return CONTENT_TOO_LARGE;
    if (value == NO_CONSUMERS.value) return NO_CONSUMERS;
    if (value == CONNECTION_FORCED.value) return CONNECTION_FORCED;
    if (value == INVALID_PATH.value) return INVALID_PATH;
    if (value == ACCESS_REFUSED.value) return ACCESS_REFUSED;
    if (value == NOT_FOUND.value) return NOT_FOUND;
    if (value == RESOURCE_LOCKED.value) return RESOURCE_LOCKED;
    if (value == PRECONDITION_FAILED.value) return PRECONDITION_FAILED;
    if (value == FRAME_ERROR.value) return FRAME_ERROR;
    if (value == SYNTAX_ERROR.value) return SYNTAX_ERROR;
    if (value == COMMAND_INVALID.value) return COMMAND_INVALID;
    if (value == CHANNEL_ERROR.value) return CHANNEL_ERROR;
    if (value == UNEXPECTED_FRAME.value) return UNEXPECTED_FRAME;
    if (value == RESOURCE_ERROR.value) return RESOURCE_ERROR;
    if (value == NOT_ALLOWED.value) return NOT_ALLOWED;
    if (value == NOT_IMPLEMENTED.value) return NOT_IMPLEMENTED;
    if (value == INTERNAL_ERROR.value) return INTERNAL_ERROR;
    throw ArgumentError("Invalid error type value $value");
  }

  static String nameOf(ErrorType value) {
    if (value == SUCCESS) return "SUCCESS";
    if (value == CONTENT_TOO_LARGE) return "CONTENT_TOO_LARGE";
    if (value == NO_CONSUMERS) return "NO_CONSUMERS";
    if (value == CONNECTION_FORCED) return "CONNECTION_FORCED";
    if (value == INVALID_PATH) return "INVALID_PATH";
    if (value == ACCESS_REFUSED) return "ACCESS_REFUSED";
    if (value == NOT_FOUND) return "NOT_FOUND";
    if (value == RESOURCE_LOCKED) return "RESOURCE_LOCKED";
    if (value == PRECONDITION_FAILED) return "PRECONDITION_FAILED";
    if (value == FRAME_ERROR) return "FRAME_ERROR";
    if (value == SYNTAX_ERROR) return "SYNTAX_ERROR";
    if (value == COMMAND_INVALID) return "COMMAND_INVALID";
    if (value == CHANNEL_ERROR) return "CHANNEL_ERROR";
    if (value == UNEXPECTED_FRAME) return "UNEXPECTED_FRAME";
    if (value == RESOURCE_ERROR) return "RESOURCE_ERROR";
    if (value == NOT_ALLOWED) return "NOT_ALLOWED";
    if (value == NOT_IMPLEMENTED) return "NOT_IMPLEMENTED";
    if (value == INTERNAL_ERROR) return "INTERNAL_ERROR";
    return null;
  }
}
