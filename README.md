# dart_amqp

![Build Status](https://github.com/achilleasa/dart_amqp/actions/workflows/ci.yaml/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/achilleasa/dart_amqp/badge.svg?branch=master)](https://coveralls.io/github/achilleasa/dart_amqp?branch=master)

Dart AMQP client implementing protocol version 0.9.1

Main features:
 - asynchronous API based on [Futures](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:async.Future) and [Streams](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart-async.Stream)
 - supports PLAIN and AMQPLAIN authentication providers while other authentication schemes can be plugged in by implementing the appropriate interface.
 - implements the entire 0.9.1 protocol specification (except basic get and recover-async).
 - supports both plain-text and TLS connections.
 - supports publish confirmations.
 - supports heartbeats.

Things not working yet:
- the driver does not currently support recovering client topologies when re-establishing connections. This feature may be implemented in a future version.

# Quick start

Listening to a queue:

```dart
import "package:dart_amqp/dart_amqp.dart";

void main() async {
  Client client = Client();

  Channel channel = await client.channel(); // auto-connect to localhost:5672 using guest credentials
  Queue queue = await channel.queue("hello");
  Consumer consumer = await queue.consume();
  consumer.listen((AmqpMessage message) {
    // Get the payload as a string
    print(" [x] Received string: ${message.payloadAsString}");

    // Or unserialize to json
    print(" [x] Received json: ${message.payloadAsJson}");

    // Or just get the raw data as a Uint8List
    print(" [x] Received raw: ${message.payload}");

    // The message object contains helper methods for
    // replying, ack-ing and rejecting
    message.reply("world");
  });
}
```

Sending messages via an exchange:
```dart
import "package:dart_amqp/dart_amqp.dart";

void main() async {

  // You can provide a settings object to override the
  // default connection settings
  ConnectionSettings settings = ConnectionSettings(
    host: "remote.amqp.server.com",
    authProvider: PlainAuthenticator("user", "pass")
  );
  Client client = Client(settings: settings);

  Channel channel = await client.channel();
  Exchange exchange = await channel.exchange("logs", ExchangeType.FANOUT);
  // We dont care about the routing key as our exchange type is FANOUT
  exchange.publish("Testing 1-2-3", null);
  client.close();
}
```

# API

See the [API documentation](https://github.com/achilleasa/dart_amqp/blob/master/API.md).

# RPC calls over AMQP

This [example](https://github.com/achilleasa/dart_amqp/tree/master/example/rpc) illustrates how to get a basic RPC server/client up and running using just the provided api calls.

The driver does not provide any helper classes for easily performing RPC calls over AMQP as not everyone needs this
functionality. If you need RPC support for your application you may want to consider using the [dart\_amqp\_rpc](https://pub.dartlang.org/packages/dart_amqp_rpc) package.

# Examples

The [example](https://github.com/achilleasa/dart_amqp/tree/master/example) folder contains implementations of the six RabbitMQ getting started [tutorials](https://www.rabbitmq.com/getstarted.html).

# Contributing

See the [Contributing Guide](https://github.com/achilleasa/dart_amqp/blob/master/CONTRIBUTING.md).


# License

dart\_amqp is distributed under the [MIT license](https://github.com/achilleasa/dart_amqp/blob/master/LICENSE).
