import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

void main(List<String> args) async {
  if (args.isEmpty || !args.every(["info", "warning", "error"].contains)) {
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
  ProcessSignal.sigint.watch().listen((_) async {
    await client.close();
    exit(0);
  });

  Channel channel = await client.channel();
  Exchange exchange =
      await channel.exchange("direct_logs", ExchangeType.DIRECT);
  Consumer consumer = await exchange.bindPrivateQueueConsumer(args);

  print(
      " [*] Waiting for [${args.join(', ')}] logs on private queue ${consumer.queue.name}. To exit, press CTRL+C");
  consumer.listen((message) {
    print(
        " [x] [Exchange: ${message.exchangeName}] [${message.routingKey}] ${message.payloadAsString}");
  });
}
