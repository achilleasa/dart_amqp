import "dart:io";
import "package:dart_amqp/dart_amqp.dart";

void main(List<String> args) {
  if (args.isEmpty ||
      !args.every((String arg) => ["info", "warning", "error"].contains(arg))) {
    print("""
    Error: invalid arguments. Please invoke as:

    dart receive_logs_direct.dart severity [severity]

    Where:
        severity = info, warning or error

    Example:
      dart receive_logs_direct.dart info error

""");
    exit(1);
  }

  Client client = Client();

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.sigint.watch().listen((_) {
    client.close().then((_) {
      exit(0);
    });
  });

  client
      .channel()
      .then((Channel channel) =>
          channel.exchange("direct_logs", ExchangeType.DIRECT))
      .then((Exchange exchange) => exchange.bindPrivateQueueConsumer(args))
      .then((Consumer consumer) {
    print(
        " [*] Waiting for [${args.join(', ')}] logs on private queue ${consumer.queue.name}. To exit, press CTRL+C");
    consumer.listen((AmqpMessage message) {
      print(
          " [x] [Exchange: ${message.exchangeName}] [${message.routingKey}] ${message.payloadAsString}");
    });
  });
}
