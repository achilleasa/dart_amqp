import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";

void main() async {
  Client client = Client();

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.sigint.watch().listen((_) async {
    await client.close();
    exit(0);
  });

  Channel channel = await client.channel();
  Queue queue = await channel.queue("hello");
  Consumer consumer = await queue.consume();
  print(" [*] Waiting for messages. To exit, press CTRL+C");
  consumer.listen((message) {
    print(" [x] Received ${message.payloadAsString}");
  });
}
