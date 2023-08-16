library dart_amqp.test.channels;

import "dart:async";

import "package:test/test.dart";

import "package:dart_amqp/src/client.dart";
import "package:dart_amqp/src/enums.dart";
import "package:dart_amqp/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

// This test expects a local running rabbitmq instance at the default port
main({bool enableLogger = true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Channels:", () {
    late Client client;

    setUp(() {
      client = Client();
    });

    tearDown(() {
      return client.close();
    });

    test("select() followed by commit()", () async {
      Channel channel = await client.channel();
      channel = await channel.select();
      channel = await channel.commit();
    });

    test("select() followed by rollback()", () async {
      Channel channel = await client.channel();
      channel = await channel.select();
      channel = await channel.rollback();
    });

    test("flow control: off", () async {
      // Rabbit does not support setting flow control to on
      Channel channel = await client.channel();
      channel = await channel.flow(true);
    });

    group("exceptions:", () {
      test("sending data on a closed channel should raise an exception",
          () async {
        Channel channel = await client.channel();
        channel = await channel.close();
        expect(
            () => channel.privateQueue(),
            throwsA((e) =>
                e is StateError && e.message == "Channel has been closed"));
      });

      test(
          "commit() on a non-transactional channel should raise a precondition-failed error",
          () async {
        try {
          Channel channel = await client.channel();
          channel = await channel.commit();
          fail("Expected an exception to be thrown");
        } catch (e) {
          expect(e, const TypeMatcher<ChannelException>());
          expect((e as ChannelException).errorType,
              equals(ErrorType.PRECONDITION_FAILED));
        }
      });

      test(
          "rollback() on a non-transactional channel should raise a precondition-failed error",
          () async {
        try {
          Channel channel = await client.channel();
          channel = await channel.rollback();
          fail("Expected an exception to be thrown");
        } catch (e) {
          expect(e, const TypeMatcher<ChannelException>());
          expect((e as ChannelException).errorType,
              equals(ErrorType.PRECONDITION_FAILED));
          expect(e.toString(),
              startsWith("ChannelException(PRECONDITION_FAILED)"));
        }
      });

      test("recover()", () async {
        Channel channel = await client.channel();
        channel = await channel.recover(true);
      });

      test(
          "channel-closing exceptions should close any active consumer streams",
          () async {
        Channel channel = await client.channel();
        Queue queue = await channel.queue("test-close-consumer-on-exception",
            autoDelete: true);
        Consumer consumer = await queue.consume();
        Completer listenerDone = Completer();
        consumer.listen((event) {}, onDone: () {
          listenerDone.complete(true);
        });

        expect(() => channel.queue("bogus", passive: true),
            throwsA((e) => e is QueueNotFoundException));
        expect(listenerDone.future, completion(equals(true)));
      });

      test("closing a channel should close any active consumer streams",
          () async {
        Channel channel = await client.channel();
        Queue queue = await channel
            .queue("test-close-consumer-on-channel-close", autoDelete: true);
        Consumer consumer = await queue.consume();
        Completer listenerDone = Completer();
        consumer.listen((event) {}, onDone: () {
          listenerDone.complete(true);
        });

        await channel.close();
        expect(listenerDone.future, completion(equals(true)));
      });
    });
  });
}
