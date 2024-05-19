part of "../../protocol.dart";

abstract class DecodedMessage {
  int get channel;

  Message? get message;

  MessageProperties? get properties;

  Uint8List? get payload;

  String get payloadAsString;

  Map get payloadAsJson;

  @override
  String toString();
}
