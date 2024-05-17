part of "../../client.dart";

class _PublishNotificationImpl implements PublishNotification {
  @override
  final Object? message;
  @override
  final MessageProperties? properties;
  @override
  bool published;

  _PublishNotificationImpl(this.message, this.properties, this.published);
}
