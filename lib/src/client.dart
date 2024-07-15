library dart_amqp.client;

import "dart:async";
import "package:dart_amqp/dart_amqp.dart";
import "package:universal_io/io.dart";
import "dart:typed_data";
import "dart:collection";

import 'package:async/async.dart';
import "package:web_socket_channel/web_socket_channel.dart";

// Internal lib dependencies
import "logging.dart";
import "protocol.dart";

part "client/base_connection_settings.dart";
part "client/impl/connection_settings.dart";
part "client/impl/websocket_connection_settings.dart";

// client interfaces
part "client/client.dart";
part "client/channel.dart";
part "client/queue.dart";
part "client/consumer.dart";
part "client/exchange.dart";
part "client/amqp_message.dart";
part "client/basicreturn_message.dart";
part "client/publish_notification.dart";

// client implementations
part "client/impl/amqp_message_impl.dart";
part "client/impl/client_impl.dart";
part "client/impl/channel_impl.dart";
part "client/impl/queue_impl.dart";
part "client/impl/consumer_impl.dart";
part "client/impl/exchange_impl.dart";
part "client/impl/basic_return_message_impl.dart";
part "client/impl/publish_notification_impl.dart";
