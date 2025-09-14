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

<details>
  <summary><strong>Web (Browser / Flutter Web)</strong></summary>

## Overview

This library supports Web via STOMP over WebSocket (RabbitMQ Web-STOMP). The Web mode focuses on publish/subscribe and consuming from already provisioned queues and exchanges. Topology management (declaring/deleting queues/exchanges) is not supported from the browser.

## What works on the Web

| Feature | Web support |
|---|---|
| Connect over WebSocket (STOMP v1.2) | ✅ |
| Consume from existing queues | ✅ |
| Publish to queues | ✅ |
| Publish to exchanges with routing keys | ✅ |
| Topic wildcards (e.g. `a.*`, `a.#`) | ✅ |
| Manual ack per message | ✅ |
| Auto ack | ✅ |
| Reply using `replyTo` | ✅ |
| Heartbeats | ✅ |
| Declare/delete queues/exchanges | ❌ |
| QoS (prefetch) changes | ❌ |
| Transactions (select/commit/rollback) | ❌ |
| Channel-level flow/recover | ❌ |
| Basic.return and publisher confirms | ❌ |

## RabbitMQ requirements

- Enable STOMP and Web-STOMP plugins:

```bash
rabbitmq-plugins enable rabbitmq_stomp rabbitmq_web_stomp
```

## NGINX reverse proxy (WebSocket)

```nginx
location /ws {
  proxy_pass http://rabbitmq:15674;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "Upgrade";
  proxy_set_header Host $host;
  proxy_read_timeout 600s;
}
```

## Web usage examples (Dart)

Connect and consume from an exchange (topic) and publish:

```dart
import 'package:dart_amqp/dart_amqp.dart';

Future<void> main() async {
  final client = Client.forWeb(
    settings: ConnectionSettings(
      host: 'your.domain.com',
      port: 443, // behind NGINX; or 15674 directly
      virtualHost: '/',
      authProvider: const PlainAuthenticator('user', 'pass'),
      connectionName: 'web_demo_${DateTime.now().millisecondsSinceEpoch}',
    ),
  );

  await client.connect();
  final channel = await client.channel();

  // Subscribe to a topic
  final exchange = await channel.exchange('test_topic_exchange', ExchangeType.TOPIC, passive: true);
  final consumer = await exchange.bindPrivateQueueConsumer(['demo.web.*']);
  consumer.listen((msg) {
    print('Topic: ${msg.routingKey} -> ${msg.payloadAsString}');
    msg.ack();
  });

  // Give the subscription a moment
  await Future.delayed(const Duration(milliseconds: 300));

  // Publish to the topic
  exchange.publish({'hello': 'world', 'ts': DateTime.now().toIso8601String()}, 'demo.web.test');
}
```

Consume and publish to an existing queue:

```dart
import 'package:dart_amqp/dart_amqp.dart';

Future<void> main() async {
  final client = Client.forWeb(
    settings: ConnectionSettings(
      host: 'your.domain.com',
      port: 443,
      virtualHost: '/',
      authProvider: const PlainAuthenticator('user', 'pass'),
    ),
  );

  await client.connect();
  final channel = await client.channel();

  final queue = await channel.queue('existing_queue', passive: true);
  final consumer = await queue.consume(noAck: false); // manual ACK
  consumer.listen((msg) {
    print('Queue: ${msg.payloadAsString}');
    msg.ack();
  });

  await Future.delayed(const Duration(milliseconds: 300));
  queue.publish({'ping': 'pong', 'ts': DateTime.now().toIso8601String()});
}
```

### Notes
- Provision queues/exchanges via AMQP or RabbitMQ Management UI; Web cannot declare them.
- Ensure `web_stomp.ws_path` and NGINX `location` match.
- The STOMP `host` header is set from `ConnectionSettings.virtualHost` and must match your RabbitMQ vhost.

</details>

---

### 🎉 **Contributors** 🎉


<div style={{textAlign: 'center', margin: '2rem 0'}}>
  <a href="https://github.com/achilleasa/dart_amqp/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=achilleasa/dart_amqp" alt="Contributors" />
  </a>
  <p style={{marginTop: '1rem', fontSize: '0.9rem', color: 'var(--ifm-color-emphasis-600)'}}>
    <strong>Made with <a href="https://contrib.rocks" target="_blank">contrib.rocks</a></strong>
  </p>
</div>

</div>