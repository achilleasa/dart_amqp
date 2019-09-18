import "package:dart_amqp/dart_amqp.dart";

void main() async {
  Client client = Client();
  Channel channel = await client.channel();
  Queue queue = await channel.queue("hello");
  queue.publish("Hello World!");
  print(" [x] Sent 'Hello World!'");
  await client.close();
}
