part of dart_amqp.enums;

class FrameType extends Enum<int> {
  static const FrameType METHOD = FrameType._(1);
  static const FrameType HEADER = FrameType._(2);
  static const FrameType BODY = FrameType._(3);
  static const FrameType HEARTBEAT = FrameType._(8);

  const FrameType._(int value) : super(value);

  String toString() => "${value}";

  static FrameType valueOf(int value) {
    FrameType fromValue = value == METHOD._value
        ? METHOD
        : value == HEADER._value
            ? HEADER
            : value == BODY._value
                ? BODY
                : value == HEARTBEAT._value ? HEARTBEAT : null;

    if (fromValue == null) {
      throw ArgumentError("Invalid frame type value ${value}");
    }
    return fromValue;
  }

  static String nameOf(FrameType value) {
    String name = value == METHOD
        ? "METHOD"
        : value == HEADER
            ? "HEADER"
            : value == BODY ? "BODY" : value == HEARTBEAT ? "HEARTBEAT" : null;

    return name;
  }
}
