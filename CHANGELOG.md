# Changelog

## 0.0.6

- Add support for custom exchanges via the `ExchangeType.custom()` constructor

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
