library dart_amqp.test.queues;

import "dart:async";

import "package:test/test.dart";

import "package:dart_amqp/src/client.dart";
import "package:dart_amqp/src/protocol.dart";
import "package:dart_amqp/src/enums.dart";
import "package:dart_amqp/src/exceptions.dart";

import "mocks/mocks.dart" as mock;

// This test expects a local running rabbitmq instance at the default port
main({bool enableLogger = true}) {
  if (enableLogger) {
    mock.initLogger();
  }

  group("Queues:", () {
    late Client client;

    setUp(() {
      client = Client();
    });

    tearDown(() {
      return client.close();
    });

    test("check if unknown queue exists", () async {
      try {
        Channel channel = await client.channel();
        await channel.queue("foo", passive: true);
        fail("Expected an exception to be thrown");
      } catch (e) {
        expect(e, const TypeMatcher<QueueNotFoundException>());
        expect((e as QueueNotFoundException).errorType,
            equals(ErrorType.NOT_FOUND));
        expect(e.toString(), startsWith("QueueNotFoundException: NOT_FOUND"));
      }
    });

    test("create private queue", () async {
      Channel channel = await client.channel();
      Queue queue = await channel.privateQueue();
      expect(queue.channel, const TypeMatcher<Channel>());
      expect(queue.name, isNotEmpty);
      expect(queue.consumerCount, equals(0));
      expect(queue.messageCount, equals(0));
    });

    test("create public queue", () async {
      Channel channel = await client.channel();
      Queue queue = await channel.queue("test_1");
      expect(queue.channel, const TypeMatcher<Channel>());
      expect(queue.name, isNotEmpty);
      expect(queue.consumerCount, equals(0));
      expect(queue.messageCount, equals(0));
    });

    test("Check the existance of a created queue", () async {
      Channel channel = await client.channel();
      Queue privateQueue = await channel.privateQueue();
      // Check existance
      Queue queue =
          await privateQueue.channel.queue(privateQueue.name, passive: true);
      expect(queue.name, equals(privateQueue.name));
    });
  });

  group("inter-queue messaging:", () {
    late Client client;
    late Client client2;

    setUp(() {
      client = Client();
      client2 = Client();
    });

    tearDown(() {
      return Future.wait([client.close(), client2.close()]);
    });

    test("queue message delivery", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_2");
      Consumer consumer = await testQueue.consume();

      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);

      consumer.listen(expectAsync1((AmqpMessage message) {
        expect(message.payloadAsString, equals("Test payload"));
        testCompleter.complete();
      }));

      // Using second client publish a message to the queue
      Channel channel2 = await client2.channel();
      Queue target = await channel2.queue(consumer.queue.name);
      target.publish("Test payload");

      return testCompleter.future;
    });

    test("queue UTF8 message delivery", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_2");
      Consumer consumer = await testQueue.consume();

      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);

      consumer.listen(expectAsync1((AmqpMessage message) {
        expect(
            message.payloadAsString, equals("This string contains ø, æ or å"));
        testCompleter.complete();
      }));

      // Using second client publish a message to the queue
      Channel channel2 = await client2.channel();
      Queue target = await channel2.queue(consumer.queue.name);
      target.publish("This string contains ø, æ or å");

      return testCompleter.future;
    });

    test("queue JSON message delivery (auto-filled content type)", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_2");
      Consumer consumer = await testQueue.consume();

      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);

      consumer.listen(expectAsync1((AmqpMessage message) {
        expect(message.payloadAsJson, equals({"message": "Test payload"}));
        expect(message.properties!.contentType, equals("application/json"));
        testCompleter.complete();
      }));

      // Using second client publish a message to the queue
      Channel channel2 = await client2.channel();
      Queue target = await channel2.queue(consumer.queue.name);
      target.publish({"message": "Test payload"});

      return testCompleter.future;
    });

    test(
        "queue JSON message delivery (auto-filled content type) with UTF8 fields",
        () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_2");
      Consumer consumer = await testQueue.consume();

      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);

      consumer.listen(expectAsync1((AmqpMessage message) {
        expect(message.payloadAsJson,
            equals({"message_ø": "This string contains ø, æ or å"}));
        expect(message.properties!.contentType, equals("application/json"));
        testCompleter.complete();
      }));

      // Using second client publish a message to the queue
      Channel channel2 = await client2.channel();
      Queue target = await channel2.queue(consumer.queue.name);
      target.publish({"message_ø": "This string contains ø, æ or å"});

      return testCompleter.future;
    });

    test(
        "queue JSON message delivery (auto-filled content type in existing persistent message property set)",
        () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_2");
      Consumer consumer = await testQueue.consume();

      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);

      // Use second accuracy
      DateTime now = DateTime.now();
      now = now.subtract(Duration(
          milliseconds: now.millisecond, microseconds: now.microsecond));

      consumer.listen(expectAsync1((AmqpMessage message) {
        expect(message.payloadAsJson, equals({"message": "Test payload"}));
        expect(message.properties!.contentType, equals("application/json"));
        expect(message.properties!.headers, equals({'X-HEADER': 'ok'}));
        expect(message.properties!.priority, equals(1));
        expect(message.properties!.corellationId, equals("123"));
        expect(message.properties!.replyTo, equals("/dev/null"));
        expect(message.properties!.expiration, equals("60000"));
        expect(message.properties!.messageId, equals("0xf00"));
        expect(message.properties!.timestamp, equals(now));
        expect(message.properties!.type, equals("test"));
        expect(message.properties!.userId, equals("guest"));
        expect(message.properties!.appId, equals("unit-test"));
        testCompleter.complete();
      }));

      // Using second client publish a message with full properties to the queue
      Channel channel2 = await client2.channel();
      Queue target = await channel2.queue(consumer.queue.name);
      target.publish({"message": "Test payload"},
          properties: MessageProperties.persistentMessage()
            ..headers = {'X-HEADER': 'ok'}
            ..priority = 1
            ..corellationId = "123"
            ..replyTo = "/dev/null"
            ..expiration = "60000" // 60 sec
            ..messageId = "0xf00"
            ..timestamp = now
            ..type = "test"
            ..userId = "guest"
            ..appId = "unit-test");

      return testCompleter.future;
    });

    test("queue message delivery with ack", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_3");
      Consumer consumer = await testQueue.consume(noAck: false);

      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);

      consumer.listen(expectAsync1((AmqpMessage message) {
        expect(message.payloadAsString, equals("Test payload"));
        message.ack();
        testCompleter.complete();
      }));

      // Using second client publish a message to the queue (request ack)
      Channel channel2 = await client2.channel();
      Queue target = await channel2.queue(consumer.queue.name);
      target.publish("Test payload", mandatory: true);

      return testCompleter.future;
    });

    test("reject delivered message", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_3");
      Consumer consumer = await testQueue.consume(noAck: false);

      expect(consumer.channel, const TypeMatcher<Channel>());
      expect(consumer.queue, const TypeMatcher<Queue>());
      expect(consumer.tag, isNotEmpty);

      consumer.listen(expectAsync1((AmqpMessage message) {
        expect(message.payloadAsString, equals("Test payload"));
        message.reject(false);
        testCompleter.complete();
      }));

      // Using second client publish a message to the queue (request ack)
      Channel channel2 = await client2.channel();
      Queue target = await channel2.queue(consumer.queue.name);
      target.publish("Test payload", mandatory: true);

      return testCompleter.future;
    });

    test("confirm published messages", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue queue = await channel.privateQueue();
      await channel.confirmPublishedMessages();
      await channel.confirmPublishedMessages(); // second call should be a no-op

      channel.publishNotifier((PublishNotification notification) {
        expect(notification.message, equals("test"));
        expect(notification.properties?.corellationId, equals("42"));
        expect(notification.published, equals(true));
        testCompleter.complete();
      });

      // Publish message and wait for broker to notify us that it has
      // successfully processed the message.
      MessageProperties msgProps = MessageProperties()..corellationId = "42";
      queue.publish("test", properties: msgProps);

      return testCompleter.future;
    });

    test("queue cancel consumer", () async {
      Completer testCompleter = Completer();

      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_3");
      Consumer consumer = await testQueue.consume(noAck: false);

      consumer.listen((AmqpMessage message) {
        fail("Received unexpected AMQP message");
      }, onDone: () {
        testCompleter.complete();
      });

      // Cancel the consumer and wait for the stream controller to close
      await consumer.cancel();

      return testCompleter.future;
    });

    test("delete queue", () async {
      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_3");
      await testQueue.delete();
    });

    test(
        "consuming with same consumer tag on same channel should return identical consumer",
        () async {
      Channel channel = await client.channel();
      Queue testQueue = await channel.queue("test_3");
      Consumer consumer1 = await testQueue.consume(consumerTag: "test_tag_1");
      Consumer consumer2 =
          await consumer1.queue.consume(consumerTag: "test_tag_1");

      expect(true, identical(consumer1, consumer2));
    });

    test("purge a queue", () async {
      Channel channel = await client.channel();
      Queue queue = await channel.queue("test_4");
      await queue.purge();
    });

    group("exceptions:", () {
      test("unsupported message payload", () async {
        Channel channel = await client.channel();
        Queue queue = await channel.queue("test_99");
        try {
          queue.publish(StreamController());
        } catch (ex) {
          expect(ex, const TypeMatcher<ArgumentError>());
          expect(
              (ex as ArgumentError).message,
              equals(
                  "Message payload should be either a Map, an Iterable, a String or an UInt8List instance"));
        }
      });

      test(
          "server closes channel after publishing message with invalid properties; next channel operation should fail",
          () async {
        Channel channel = await client.channel();
        Queue queue = await channel.queue("test_100");
        try {
          queue.publish("invalid properties test",
              properties: MessageProperties()..expiration = "undefined");
          await queue.channel.queue("other_queue");
        } catch (ex) {
          expect(ex, const TypeMatcher<ChannelException>());
          expect(
              ex.toString(),
              equals(
                  "ChannelException(PRECONDITION_FAILED): PRECONDITION_FAILED - invalid expiration 'undefined': no_integer"));
        }
      });

      test(
          "trying to publish to a channel closed by a prior invalid published message; next publish should fail",
          () async {
        Channel channel = await client.channel();
        Queue queue = await channel.queue("test_100");
        queue.publish("invalid properties test",
            properties: MessageProperties()..expiration = "undefined");
        try {
          await Future.delayed(const Duration(seconds: 1));
          queue.publish("test");
        } catch (ex) {
          expect(ex, const TypeMatcher<ChannelException>());
          expect(
              ex.toString(),
              equals(
                  "ChannelException(PRECONDITION_FAILED): PRECONDITION_FAILED - invalid expiration 'undefined': no_integer"));
        }
      });
    });
  });
}
