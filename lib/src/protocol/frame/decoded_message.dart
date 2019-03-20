part of dart_amqp.protocol;

abstract class DecodedMessage {
  int get channel;

  Message get message;

  MessageProperties get properties;

  Uint8List get payload;

  String get payloadAsString;

  Map get payloadAsJson;

  String toString();
}
