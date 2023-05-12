# Changelog

## 0.2.5

- Merged [#95](https://github.com/achilleasa/dart_amqp/pull/95) to guard against sending heartbeats if the underlying socket is closed

## 0.2.4

- Merged [#89](https://github.com/achilleasa/dart_amqp/pull/89) to allow clients to specify a connection name as part of the `ConnectionSettings` object for debugging purposes.
- Merged [#90](https://github.com/achilleasa/dart_amqp/pull/90) to ensure that the API docs for `ConnectionSettings` are up to date.

## 0.2.3

- Merged [#85](https://github.com/achilleasa/dart_amqp/pull/85) to fix some minor lint issues that were discovered after bumping the lint_core dep version.

## 0.2.2

- Merged [#78](https://github.com/achilleasa/dart_amqp/pull/78) to support queue properties for `bindQueueConsumer` and `bindPrivateQueueConsumer`.
- Merged [#80](https://github.com/achilleasa/dart_amqp/pull/80) to expose the `deliveryTag` field from `AmqpMessage` instances.
- Merged [#82](https://github.com/achilleasa/dart_amqp/pull/82) to support changing the value of the `global` parameter when invoking `channel.qos()`.
- Merged [#84](https://github.com/achilleasa/dart_amqp/pull/84) to support heartbeats.

## 0.2.1

- Merged [#61](https://github.com/achilleasa/dart_amqp/pull/61) to support
publish confirmations.
- Merged [#63](https://github.com/achilleasa/dart_amqp/pull/63) to allow applications
to register a handler for deciding how to deal with TLS certificate-related errors.
- Merged [#64](https://github.com/achilleasa/dart_amqp/pull/64) to fix a bug
where calls specifying `noWait: true` would obtain a Future result that would never complete.
- Merged [#65](https://github.com/achilleasa/dart_amqp/pull/65) to allow clients
with read-only access to the broker to skip the declaration of the queues that they intend to consume from.
- Merged [#66](https://github.com/achilleasa/dart_amqp/pull/66) which fixes table layout issues in the documentation.

## 0.2.0

- Merged [#55](https://github.com/achilleasa/dart_amqp/pull/55) which enables
null-safety for the package.
- Bumped minor version since null safety is a breaking change.

## 0.1.5

- Merged [#49](https://github.com/achilleasa/dart_amqp/pull/49) to fix a bug
that prevented re-opening a client that was previously closed.

## 0.1.4

- Merged [#30](https://github.com/achilleasa/dart_amqp/pull/30) to add support
for binding to a named exchange queue.

## 0.1.3

- Fixes #31 (Issues decoding strings with ØÆÅ) via [#32](https://github.com/achilleasa/dart_amqp/pull/32)
- Add support for connecting to rabbitmq over TLS via [#33](https://github.com/achilleasa/dart_amqp/pull/33)

## 0.1.2

 Merged [#22](https://github.com/achilleasa/dart_amqp/pull/22), [#23](https://github.com/achilleasa/dart_amqp/pull/23),
 [#27](https://github.com/achilleasa/dart_amqp/pull/27), [#28](https://github.com/achilleasa/dart_amqp/pull/27)
 to address issues with Dart 2.5

## 0.1.1

- Merged [#19](https://github.com/achilleasa/dart_amqp/pull/19) to improve support for `HEADER` exchanges.

## 0.1.0

- Migrate to Dart 2

## 0.0.9

- Merged [#14](https://github.com/achilleasa/dart_amqp/pull/14) and [#15](https://github.com/achilleasa/dart_amqp/pull/15)
to fix some type errors reported by dartanalyzer when running with Dart2/Flutter.

## 0.0.6

- Add support for [custom exchanges](https://github.com/achilleasa/dart_amqp/pull/7) via the `ExchangeType.custom()` constructor

## 0.0.5

- Fixes #6 (stack overflow when processing large TCP packets)

## 0.0.4

- Merged Faisal Abid's [PR](https://github.com/achilleasa/dart_amqp/pull/5) that
forces the client to request a 0 heartbeat timeout

## 0.0.3

- Merged Raj Maniar's [PR](https://github.com/achilleasa/dart_amqp/pull/3) that
allows users to register a listener for exceptions caught by the client

## 0.0.2

- Merged Raj Maniar's [PR](https://github.com/achilleasa/dart_amqp/pull/2) that adds support for handling basicReturn
messages

## 0.0.1

- Initial version
