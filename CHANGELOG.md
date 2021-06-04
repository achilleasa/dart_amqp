# Changelog

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
