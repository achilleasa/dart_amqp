part of "../client.dart";

abstract class PublishNotification {
  Object? get message;
  MessageProperties? get properties;
  bool get published;
}
