import "package:dart_amqp/dart_amqp.dart";

void main(List<String> args) {
  Client client = Client();
  client
      .channel()
      .then((Channel channel) => channel.exchange("logs", ExchangeType.FANOUT))
      .then((Exchange exchange) {
    String message = args.join(' ');
    // We dont care about the routing key as our exchange type is FANOUT
    exchange.publish(message, null);
    print(" [x] Sent ${message}");
    return client.close();
  });
}
