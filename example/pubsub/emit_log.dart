import "package:dart_amqp/dart_amqp.dart";

void main(List<String> args) async {
  Client client = Client();
  Channel channel = await client.channel();
  Exchange exchange = await channel.exchange("logs", ExchangeType.FANOUT);

  String message = args.join(' ');
  // We dont care about the routing key as our exchange type is FANOUT
  exchange.publish(message, null);
  print(" [x] Sent $message");
  await client.close();
}
