part of dart_amqp.enums;

class ExchangeType extends Enum<String> {
  static const ExchangeType FANOUT = const ExchangeType._("fanout");
  static const ExchangeType DIRECT = const ExchangeType._("direct");
  static const ExchangeType TOPIC = const ExchangeType._("topic");
  static const ExchangeType HEADERS = const ExchangeType._("headers");

  const ExchangeType._(String value) : super(value);

  String toString() => "${value}";

  static ExchangeType valueOf(String value) {
    ExchangeType fromValue = value == FANOUT._value ? FANOUT :
                             value == DIRECT._value ? DIRECT :
                             value == TOPIC._value ? TOPIC :
                             value == HEADERS._value ? HEADERS : null;

    if (fromValue == null) {
      throw new ArgumentError("Invalid exchange type value ${value}");
    }
    return fromValue;
  }

  static String nameOf(ExchangeType value) {
    String name = value == FANOUT ? "FANOUT" :
                  value == DIRECT ? "DIRECT" :
                  value == TOPIC ? "TOPIC" :
                  value == HEADERS ? "HEADERS" : null;

    return name;
  }
}

class CustomExchangeType extends ExchangeType {

  final bool routingKeyRequired;

  const CustomExchangeType(String value, {this.routingKeyRequired:true}):super._(value);

  static String nameOf(ExchangeType value) => value is CustomExchangeType ? value.toString().toUpperCase(): ExchangeType.nameOf(value);

}