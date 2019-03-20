part of dart_amqp.enums;

class ExchangeType extends BaseExchange<String> {
  static const ExchangeType FANOUT = ExchangeType._("fanout");
  static const ExchangeType DIRECT = ExchangeType._("direct");
  static const ExchangeType TOPIC = ExchangeType._("topic");
  static const ExchangeType HEADERS = ExchangeType._("headers");

  const ExchangeType._(String value) : super._(value, false);

  const ExchangeType.custom(String value) : super._(value, true);

  String toString() => "${value}";

  static ExchangeType valueOf(String value) {
    ExchangeType fromValue = value == FANOUT._value
        ? FANOUT
        : value == DIRECT._value
            ? DIRECT
            : value == TOPIC._value
                ? TOPIC
                : value == HEADERS._value
                    ? HEADERS
                    : ExchangeType.custom(value);

    return fromValue;
  }

  static String nameOf(ExchangeType value) {
    String name = value == FANOUT
        ? "FANOUT"
        : value == DIRECT
            ? "DIRECT"
            : value == TOPIC
                ? "TOPIC"
                : value == HEADERS
                    ? "HEADERS"
                    : value.isCustom ? "CUSTOM" : null;

    return name;
  }
}

class BaseExchange<T> extends Enum<T> {
  final bool isCustom;

  const BaseExchange._(T value, this.isCustom) : super(value);
}
