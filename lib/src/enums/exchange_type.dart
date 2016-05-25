part of dart_amqp.enums;

class ExchangeType extends BaseExchange {
  static const ExchangeType FANOUT = const ExchangeType._("fanout");
  static const ExchangeType DIRECT = const ExchangeType._("direct");
  static const ExchangeType TOPIC = const ExchangeType._("topic");
  static const ExchangeType HEADERS = const ExchangeType._("headers");

  const ExchangeType._(String value) : super(value, false);

  const ExchangeType.custom(String value) : super(value, true);

  String toString() => "${value}";

  static ExchangeType valueOf(String value) {
    ExchangeType fromValue = value == FANOUT._value ? FANOUT :
                             value == DIRECT._value ? DIRECT :
                             value == TOPIC._value ? TOPIC :
                             value == HEADERS._value ? HEADERS : new ExchangeType.custom(value);

    if (fromValue == null) {
      throw new ArgumentError("Invalid exchange type value ${value}");
    }
    return fromValue;
  }

  static String nameOf(ExchangeType value) {
    String name = value == FANOUT ? "FANOUT" :
                  value == DIRECT ? "DIRECT" :
                  value == TOPIC ? "TOPIC" :
                  value == HEADERS ? "HEADERS" :
                  value.isCustom ? "CUSTOM" : null;

    return name;
  }
}

class BaseExchange extends Enum<String> {

  final bool isCustom;

  const BaseExchange(String value, this.isCustom):super(value);

}