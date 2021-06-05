part of dart_amqp.protocol;

class MessageProperties {
  String? contentType;
  String? contentEncoding;
  Map<String, Object?>? headers;
  int? deliveryMode;
  int? priority;
  String? corellationId;
  String? replyTo;
  String? expiration;
  String? messageId;
  DateTime? timestamp;
  String? type;
  String? userId;
  String? appId;

  MessageProperties();

  MessageProperties.persistentMessage() {
    persistent = true;
  }

  /// Flag the message as persistent or transient based on the value of
  /// [isPersistent]
  set persistent(bool isPersistent) => deliveryMode = isPersistent ? 2 : 1;
}
