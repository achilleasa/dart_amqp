import "dart:io";
import "package:dart_amqp/dart_amqp.dart";

void main(List<String> args) {
  if (args.isEmpty) {
    print("""
    Error: invalid arguments. Please invoke as:

    dart receive_logs_topic.dart routing-key [routing-key]

    Where:
        routing-key = dot (.) delimited value like anonymous.info or kernel.error

    Example:
      dart receive_logs_topic.dart *.info

""");
    exit(1);
  }

  Client client = new Client();

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.SIGINT.watch().listen((_) {
    client.close().then((_) {
      exit(0);
    });
  });

  client
  .channel()
  .then((Channel channel) => channel.exchange("topic_logs", ExchangeType.TOPIC))
  .then((Exchange exchange) => exchange.bindPrivateQueueConsumer(args))
  .then((Consumer consumer) {
    print(" [*] Waiting for [${args.join(', ')}] logs on private queue ${consumer.queue.name}. To exit, press CTRL+C");
    consumer.listen((AmqpMessage message) {
      print(" [x] [Exchange: ${message.exchangeName}] [${message.routingKey}] ${message.payloadAsString}");
    });
  });

}