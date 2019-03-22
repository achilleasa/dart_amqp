part of dart_amqp.protocol;

abstract class Header {
  void serialize(TypeEncoder encoder);
}
