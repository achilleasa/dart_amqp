part of dart_amqp.exceptions;

class HeartbeatTimeoutException extends FatalException {
  HeartbeatTimeoutException()
      : super(
            'Did not receive any traffic for more than 2 heartbeat intervals');

  @override
  String toString() {
    return 'HeartbeatTimeoutException: $message';
  }
}
