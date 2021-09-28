part of dart_amqp.client;

abstract class PublishNotification {
  Object? get message;
  MessageProperties? get properties;
  bool get published;
}
