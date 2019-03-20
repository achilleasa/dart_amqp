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
    if (value == FANOUT.value) return FANOUT;
    if (value == DIRECT.value) return DIRECT;
    if (value == TOPIC.value) return TOPIC;
    if (value == HEADERS.value) return HEADERS;
    return ExchangeType.custom(value);
  }

  static String nameOf(ExchangeType value) {
    if (value == FANOUT) return "FANOUT";
    if (value == DIRECT) return "DIRECT";
    if (value == TOPIC) return "TOPIC";
    if (value == HEADERS) return "HEADERS";
    if (value.isCustom) return "CUSTOM";
    return null;
  }
}

class BaseExchange<T> extends Enum<T> {
  final bool isCustom;

  const BaseExchange._(T value, this.isCustom) : super(value);
}
