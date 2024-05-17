part of "../client.dart";

abstract class Consumer {
  /// Get the consumer tag.
  String get tag;

  /// Get the [Channel] where this consumer was declared.
  Channel get channel;

  /// Get the [Queue] where this consumer is bound.
  Queue get queue;

  /// Bind [onData] listener to the stream of [AmqpMessage] that is emitted by the consumer.
  ///
  /// You can also define an optional [onError] method that will handle stream errors and an
  /// [onDone] method to be invoked when the stream closes.
  StreamSubscription<AmqpMessage> listen(
      void Function(AmqpMessage event) onData,
      {Function onError,
      void Function() onDone,
      bool cancelOnError});

  /// Cancel the consumer and return a [Future<Consumer>] to the cancelled consumer.
  Future<Consumer> cancel({bool noWait = false});
}
