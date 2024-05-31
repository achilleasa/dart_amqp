part of "../client.dart";

class ConnectionSettings {
  // The host to connect to
  String host;

  // The port to connect to
  int port;

  // The connection vhost that will be sent to the server
  String virtualHost;

  // The max number of reconnection attempts before declaring a connection as unusable
  int maxConnectionAttempts;

  // The time to wait  before trying to reconnect
  Duration reconnectWaitTime;

  // Authentication provider
  Authenticator authProvider;

  // Protocol version
  int amqpProtocolVersion = 0;
  int amqpMajorVersion = 0;
  int amqpMinorVersion = 9;
  int amqpRevision = 1;

  // Tuning settings
  TuningSettings tuningSettings;

  // TLS settings (if TLS connection is required)
  SecurityContext? tlsContext;
  bool Function(X509Certificate)? onBadCertificate;

  // Connection identifier
  String? connectionName;

  // The time to wait for socket connection to be established
  Duration? connectTimeout;

  ConnectionSettings({
    this.host = "127.0.0.1",
    this.port = 5672,
    this.virtualHost = "/",
    this.authProvider = const PlainAuthenticator("guest", "guest"),
    this.maxConnectionAttempts = 1,
    this.reconnectWaitTime = const Duration(milliseconds: 1500),
    TuningSettings? tuningSettings,
    this.tlsContext,
    this.onBadCertificate,
    this.connectionName,
    this.connectTimeout,
  }) : tuningSettings = tuningSettings ?? TuningSettings();
}
