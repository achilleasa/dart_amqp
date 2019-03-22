part of dart_amqp.enums;

class FrameType extends Enum<int> {
  static const FrameType METHOD = FrameType._(1);
  static const FrameType HEADER = FrameType._(2);
  static const FrameType BODY = FrameType._(3);
  static const FrameType HEARTBEAT = FrameType._(8);

  const FrameType._(int value) : super(value);

  String toString() => "${value}";

  static FrameType valueOf(int value) {
    if (value == METHOD.value) return METHOD;
    if (value == HEADER.value) return HEADER;
    if (value == BODY.value) return BODY;
    if (value == HEARTBEAT.value) return HEARTBEAT;
    throw ArgumentError("Invalid frame type value $value");
  }

  static String nameOf(FrameType value) {
    if (value == METHOD) return "METHOD";
    if (value == HEADER) return "HEADER";
    if (value == BODY) return "BODY";
    if (value == HEARTBEAT) return "HEARTBEAT";
    return null;
  }
}
