part of dart_amqp.enums;

/**
 * An abstract class for modeling enums
 */
abstract class Enum<T> {

  final T _value;

  const Enum(this._value);

  T get value => _value;

}