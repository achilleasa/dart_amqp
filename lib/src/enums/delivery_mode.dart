part of dart_amqp.enums;

class DeliveryMode extends Enum<int> {
  static const DeliveryMode TRANSIENT = DeliveryMode._(1);
  static const DeliveryMode PERSISTENT = DeliveryMode._(2);

  const DeliveryMode._(int value) : super(value);

  static DeliveryMode valueOf(int value) {
    if (value == TRANSIENT.value) return TRANSIENT;
    if (value == PERSISTENT.value) return PERSISTENT;
    throw ArgumentError("Invalid delivery mode value $value");
  }

  static String nameOf(DeliveryMode value) {
    if (value == TRANSIENT) return "TRANSIENT";
    if (value == PERSISTENT) return "PERSISTENT";
    return null;
  }
}
