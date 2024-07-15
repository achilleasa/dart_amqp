part of "../client.dart";

abstract class BaseConnectionSettings {
  // The host to connect to
  String? host;

  // The port to connect to
  int? port;

  // The uri to connect to websocket. Use either host and url
  Uri? uri;

  // The connection vhost that will be sent to the server
  abstract String virtualHost;

  // The max number of reconnection attempts before declaring a connection as unusable
  abstract int maxConnectionAttempts;

  // The time to wait  before trying to reconnect
  abstract Duration reconnectWaitTime;

  // Authentication provider
  abstract Authenticator authProvider;

  // Protocol version
  int amqpProtocolVersion = 0;
  int amqpMajorVersion = 0;
  int amqpMinorVersion = 9;
  int amqpRevision = 1;

  // Tuning settings
  abstract TuningSettings tuningSettings;

  // TLS settings (if TLS connection is required)
  SecurityContext? tlsContext;
  bool Function(X509Certificate)? onBadCertificate;

  // Connection identifier
  String? connectionName;

  // The time to wait for socket connection to be established
  Duration? connectTimeout;
}
