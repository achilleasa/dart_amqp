import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

void main(List<String> args) async {
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

  Client client = Client();

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.sigint.watch().listen((_) async {
    await client.close();
    exit(0);
  });

  Channel channel = await client.channel();
  Exchange exchange = await channel.exchange("topic_logs", ExchangeType.TOPIC);
  Consumer consumer = await exchange.bindPrivateQueueConsumer(args);
  print(
      " [*] Waiting for [${args.join(', ')}] logs on private queue ${consumer.queue.name}. To exit, press CTRL+C");
  consumer.listen((message) {
    print(
        " [x] [Exchange: ${message.exchangeName}] [${message.routingKey}] ${message.payloadAsString}");
  });
}
