part of dart_amqp.enums;

/// An abstract class for modeling enums
abstract class Enum<T> {
  final T value;

  const Enum(this.value);
}
