# Api

## Client

### Connection settings

The [ConnectionSettings](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/client/connection_settings.dart) class allows you to override the default connection settings used by the AMQP client. An instance of this class can be passed to the **settings** named parameter.

The class constructor supports the following named parameters:

| Parameter name        | Default value                                                                                                                                                          | Description
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| host                  | 127.0.0.1                                                                                                                                                              | The host to connect to.
| port                  | 5672                                                                                                                                                                   | The port to connect to.
| virtualHost           | "/"                                                                                                                                                                    | The AMQP virtual host parameter.
| authProvider          | [PlainAuthenticationProvider](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/authentication/plain_authenticator.dart) with "**guest:guest**" credentials. | An authentication provider instance to use. See the section on [authentication](#authentication-providers) for more info.
| maxConnectionAttempts | 1                                                                                                                                                                      | The number of connection attempts till a connection error is reported.
| reconnectWaitTime     | 1500ms                                                                                                                                                                 | A [Duration](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:core.Duration) specifying the time between reconnection attempts.
| tuningSettings        | null                                                                                                                                                                   | A [TuningSettings](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/protocol/io/tuning_settings.dart) instance to use. If not specified, the [default](#tuning-settings) tuning settings will be used.
| tlsContext            | null                                                                                                                                                                   | A [SecurityContext](https://api.dart.dev/stable/2.18.5/dart-io/SecurityContext-class.html) with the required TLS settings for connecting to the broker. If not specified, the client will attempt to establish a non-TLS connection instead.
| onBadCertificate      | null                                                                                                                                                                   | A user-defined function for deciding whether the certificate presented by the broker is valid.
| connectionName        | ""                                                                                                                                                                     | A client-provided connection name which can help to identify this connection in server logs.

### Authentication providers

The driver comes with two authentication providers, [PlainAuthenticationProvider](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/authentication/plain_authenticator.dart) and [AmqPlainAuthenticator](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/authentication/amq_plain_authenticator.dart).

To support other types of authentication you can roll your own authentication provider by implementing the [Authenticator](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/authentication/authenticator.dart) interface.

### Tuning settings

[TuningSettings](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/protocol/io/tuning_settings.dart) control the data flow between the client and the server. Normally,
you don't have to deal with tuning at the application level. The client will use the default values as specified by the protocol specification and adjust them according to the server suggestions during the initial connection handshake.

The class exposes the following parameters:

| Param name      | Default value    | Description
|-----------------|------------------|----------------------
| maxChannels     | 0 (no limit)     | The maximum number of channels that can be opened by the client. When set to zero, the maximum number of channels is 65535.
| maxFrameSize    | 4096 bytes       | The maximum frame size that can be parsed by the client. According to the spec, this is set to a high-enough initial value so that the client can parse the messages exchanged during the handshake. The client will negotiate with the server during the handshake phase and adjust this value upwards.
| heartbeatPeriod | 0 sec            | The preferred heartbeat period (or `Duration.zero` to disable heartbeats) expressed as a [Duration](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:core.Duration) object.


### Creating a new client

To create a new client use the [Client](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/client/client.dart) factory constructor. The constructor accepts the optional
named parameter `settings` that can be used to override the default connection settings for more advanced use-cases. For instance, if you are trying to connect to a rabbit instance
over TLS, you can provide a `SecurityContext` which specifies the certificates to use for establishing the secure connection.

The client will not automatically establish a connection when the client instance is created but instead will connect lazily when its methods are invoked. If you wish
to establish a connection beforehand use the `connect` method. 

The following table summarizes the methods available to an AMQP client. For detailed documentation on each method and its arguments please consult the class [documentation](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/client/client.dart).

| Method             |  Description
|--------------------|------------------
| connect()          | Connect to the AMQP server and return a `Future` to be completed on a successfull connection.
| close()            | Clean up any open channels and shutdown the connection. Returns a `Future` to be completed when the shutdown is complete.
| channel()	     | Allocate a user channel and return a `Future<Channel>`.
| errorListener()    | Register a listener for exceptions caught by the client.

### Heartbeat support 

Heartbeat support will be enabled if both the client and the server specify a
non-zero (> 1s) heartbeat period during the initial connection handshake flow.
The effective heartbeat period is calculated as the **minimum** value requested
by the client and the server.

If the effective heartbeat period is zero, heartbeat support is disabled.

When heartbeats are enabled, the client will start sending heartbeat messages 
to the server in the background. At the same time, the client will monitor 
incoming messages and will raise a [HeartbeatFailedException](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/exceptions/heartbeat_failed_exception.dart)
if the server does not send any message within the agreed upon period.

Clients can specify their preferred heartbeat period when creating the client 
as follows:

```dart
Client client = Client(
  settings: ConnectionSettings(
    tuningSettings: TuningSettings(
      heartbeatPeriod: const Duration(seconds: 60),
    ),
  ),
);
```

After a successful connection (e.g. `await client.connect()`), the negotiated 
heartbeat period can be inspected via `client.tuningSettings.heartbeatPeriod`.

## Channels

The following table summarizes the methods available to an AMQP channel obtained via the `channel()` method of a `client` instance. For detailed documentation on each method and its arguments please consult the class [documentation](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/client/channel.dart).

| Method                     | Description
|----------------------------|------------------
| close()                    | Close the channel and abort any pending operations.
| queue()                    | Define a named queue.
| privateQueue()             | Define a private queue with a random name that will be deleted when the channel closes.
| exchange()                 | Define an exchange that can be used to route messages to multiple recipients.
| qos()                      | Manage the QoS settings for the channel (prefetech size & count).
| ack()                      | Acknowledge a message by its id.
| select()                   | Begin a transaction.
| commit()                   | Commit a transaction.
| rollback()                 | Rollback a transaction.
| flow()                     | Control message flow.
| recover()                  | Recover unacknowledged messages.
| basicReturnListener()      | Get a StreamSubscription for handling undelivered messages.
| confirmPublishedMessages() | Request that the broker ACKs/NACKs the handling of published messages.
| publishNotifier()          | Register a listener for publish notifications emitted by the broker.

The `confirmPublishedMessages` and `publishNotifier` methods leverage the _publisher confirms_
[extension](https://www.rabbitmq.com/confirms.html#publisher-confirms). 

Notifications obtained using this mechanism only guarantee that the broker has
either processed (persisted) a published message successfully or it has dropped
it (e.g. out of disk space). Applications should never assume that receiving an
ACK from the broker for a published message means that a consumer has
successfully processed the message. As demonstrated by [examples/confirm](https://github.com/achilleasa/dart_amqp/blob/master/examples/confirm),
the broker will ACK messages published to a queue even if there are no consumers listening
on the other end.

## Exchanges

The following table summarizes the methods available to an AMQP exchange declared via the the `exchange()` method of a `channel` instance. For detailed documentation on each method and its arguments please consult the class [documentation](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/client/exchange.dart).

| Method                     | Description
|----------------------------|------------------
| name()                     | A getter for the exchange name.
| type()                     | A getter for the exchange [type](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/enums/exchange_type.dart).
| channel()                  | A getter for the [channel](#channels) where this exchange was declared.
| delete()                   | Delete the exchange.
| publish()                  | Publish message using a routing key
| bindPrivateQueueConsumer() | Convenience method that allocates a private [queue](#queues), binds it to the exchange via a routing key and returns a [consumer](#consumers) for processing messages.
| bindQueueConsumer()        | Convenience method that allocates a named [queue](#queues), binds it to the exchange via a routing key and returns a [consumer](#consumers) for processing messages.

## Queues

The following table summarizes the methods available to an AMQP queue obtained via the `queue()` or `privateQueue` methods of a `channel` instance. For detailed documentation on each method and its arguments please consult the class [documentation](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/client/queue.dart).

| Method             |  Description
|--------------------|------------------
| name()             | A getter for the queue name.
| channel()          | A getter for the [channel](#channels) where this queue was declared.
| delete()           | Delete the queue.
| purge()            | Purge any queued messages that are not waiting for acknowledgment.
| bind()             | Bind queue to an [exchange](#exchanges) via a routing key.
| unbind()           | Unbind queue from an [exchange](#exchanges) where it was bound via a routing key.
| publish()          | Publish a message to the queue.
| consume()          | Return a [consumer](#consumers) for processing incoming queue messages.

## Consumers

The following table summarizes the methods available to an AMQP consumer  obtained via the `consume()` method of a `queue` instance or the `bindPrivateQueueConsumer()` method of an `exchange` instance. For detailed documentation on each method and its arguments please consult the class [documentation](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/client/consumer.dart).

| Method             |  Description
|--------------------|------------------
| tag()              | A getter for the tag identifying this consumer.
| channel()          | A getter for the [channel](#channels) where this consumer was declared.
| queue()            | A getter for the [queue](#queues) this consumer is bound on.
| listen()           | Bind a listener to emited [AmqpMessage](#messages) events.
| cancel()           | Cancel the consumer.

## Messages

Queue consumers are essentially StreamControllers that emit a `Stream<AmqpMessage>`. The `AmqpMessage` class wraps the
payload of the incoming message as well as the incoming message properties
and provides helper methods for replying, ack-ing and rejecting messages. The following table summarizes the methods provided by `AmqpMessage`.  For detailed documentation on each method and its arguments please consult the class [documentation](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/client/amqp_message.dart).

| Method            | Description
|-------------------|------------------
| payload()         | A getter for retrieving the raw message paylaod as an Uint8List.
| payloadAsString() | A getter for retrieving the message payload as an UTF8 String.
| payloadAsJson()   | A getter for retrieving the message payload as a parsed JSON document.
| exchangeName()    | A getter for the [exchange](#exchanges) where the message was published.
| routingKey()      | A getter for the routing key used for publishing this message.
| properties()      | A getter for retrieving message [properties](https://github.com/achilleasa/dart_amqp/blob/master/lib/src/protocol/messages/message_properties.dart).
| ack()             | Acknowledge this message.
| reply()           | Reply to the message sender with a new message.
| reject()          | Reject this message.

## Error handling

All api methods return back `Future`. If the server reports an error then the driver will complete the future with the error and mark the channel as closed. 

When the application catches a server error, it should throw away the current channel and allocate a new one for further interaction with the server. Any attempt to invoke a method on a closed channel will cause an exception to be thrown.

The application can also register an error listener for handling socket and protocol exceptions via the `errorListener()` method provided by the client.

## Logger support

The driver manages logging using the [logging](https://pub.dartlang.org/packages/logging) package.

If your application uses hierarchical logging you can control the logger output using `dart_amqp.Connection` as the logger name.


## Bindings generator tool

The AMQP message [bindings](https://github.com/achilleasa/dart_amqp/tree/master/lib/src/protocol/messages/bindings) were automatically generated by processing the XML version of the amqp protocol specification (available [here](https://www.rabbitmq.com/resources/specs/amqp0-9-1.xml)). The source for the bindings generator is available in the [tool](https://github.com/achilleasa/dart_amqp/blob/master/tool) folder.
