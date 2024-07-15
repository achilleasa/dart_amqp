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
  channel = await channel.qos(0, 1);
  Queue queue = await channel.queue("task_queue", durable: true);
  Consumer consumer = await queue.consume(noAck: false);
  print(" [*] Waiting for messages. To exit, press CTRL+C");
  consumer.listen((message) {
    String payload = message.payloadAsString;
    print(" [x] Received $payload");
    // Emulate a long task by sleeping 1 second for each '.' character in message
    sleep(Duration(seconds: payload.split(".").length));
    print(" [x] Done");

    // Ack message so it is marked as processed
    message.ack();
  });
}
