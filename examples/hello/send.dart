import "package:dart_amqp/dart_amqp.dart";

void main(){
  Client client = new Client();
  client
    .channel()
    .then((Channel channel) => channel.queue("hello"))
    .then((Queue queue){
      queue.publish("Hello World!");
      print(" [x] Sent 'Hello World!'");
      return client.close();
  });
}