# dart_ampq

[![Build Status](https://drone.io/github.com/achilleasa/dart_amqp/status.png)](https://drone.io/github.com/achilleasa/dart_amqp/latest)
[![Coverage Status](https://coveralls.io/repos/achilleasa/dart_amqp/badge.svg)](https://coveralls.io/r/achilleasa/dart_amqp)

Dart AMQP client implementing protocol version 0.9.1

Main features:
 - asynchronous API based on [Futures](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:async.Future) and [Streams](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart-async.Stream)
 - supports PLAIN and AMQPLAIN authentication providers while other authentication schemes can be plugged in by implementing the appropriate interface.
 - implements the entire 0.9.1 protocol specification (except basic get, return and recover-async)

Things not working yet:
- the driver does not currently support recovering client topologies when re-establishing connections. This feature may be implemented in a future version. 
- heartbeats. The driver will process

# Quick start

Listening to a queue:

```dart
import "package:dart_amqp/dart_amqp.dart";

void main() {
  Client client = new Client();

  client
  .channel() // auto-connect to localhost:5672 using guest credentials
  .then((Channel channel) => channel.queue("hello"))
  .then((Queue queue) => queue.consume())
  .then((Consumer consumer) => consumer.listen((AmqpMessage message) {
    // Get the payload as a string
    print(" [x] Received string: ${message.payloadAsString}");

    // Or unserialize to json
    print(" [x] Received json: ${message.payloadAsJson}");

    // Or just get the raw data as a Uint8List
    print(" [x] Received raw: ${message.payload}");
    
    // The message object contains helper methods for 
    // replying, ack-ing and rejecting
    message.reply("world");
  }));
}
```

Sending messages via an exchange:
```dart
import "package:dart_amqp/dart_amqp.dart";

void main() {
  
  // You can provide a settings object to override the
  // default connection settings
  ConnectionSettings settings = new ConnectionSettings(
      host : "remote.amqp.server.com",
      authProvider : new PlainAuthenticator("user", "pass")
  );
  Client client = new Client(settings : settings);
  
  client
  .channel()
  .then((Channel channel) => channel.exchange("logs", ExchangeType.FANOUT))
  .then((Exchange exchange) {
    // We dont care about the routing key as our exchange type is FANOUT
    exchange.publish("Testing 1-2-3", null);
    return client.close();
  });
}
```

# Api

See the [Api documentation](https://github.com/achilleasa/dart_amqp/blob/master/API.md).

# RPC calls over AMQP

This [example](https://github.com/achilleasa/dart_amqp/tree/master/examples/rpc) illustrates how to get a basic RPC server/client up and running using just the provided api calls. 

The driver does not provide any helper classes for easily performing RPC calls over AMQP as not everyone needs this
functionality. If you need RPC support for your application you may want to consider using the [dart\_amqp\_rpc](https://pub.dartlang.org/packages/dart_amqp_rpc) package.

# Examples

The [examples](https://github.com/achilleasa/dart_amqp/tree/master/examples) folder contains implementations of the six RabbitMQ getting started [tutorials](https://www.rabbitmq.com/getstarted.html).

# Contributing

See the [Contributing Guide](https://github.com/achilleasa/dart_cassandra_cql/blob/master/CONTRIBUTING.md).


# License

dart\_amqp is distributed under the [MIT license](https://github.com/achilleasa/dart_amqp/blob/master/LICENSE).
