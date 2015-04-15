import "dart:io";
import "package:dart_amqp/dart_amqp.dart";

void main() {
  Client client = new Client();

  // Setup a signal handler to cleanly exit if CTRL+C is pressed
  ProcessSignal.SIGINT.watch().listen((_) {
    client.close().then((_) {
      exit(0);
    });
  });

  client
  .channel()
  .then((Channel channel) => channel.qos(0, 1))
  .then((Channel channel) => channel.queue("task_queue", durable: true))
  .then((Queue queue) => queue.consume(noAck : false))
  .then((Consumer consumer) {
    print(" [*] Waiting for messages. To exit, press CTRL+C");
    consumer.listen((AmqpMessage message) {
      String payload = message.payloadAsString;
      print(" [x] Received ${payload}");
      // Emulate a long task by sleeping 1 second for each '.' character in message
      sleep(new Duration(seconds : payload.split(".").length));
      print(" [x] Done");

      // Ack message so it is marked as processed
      message.ack();
    });
  });

}