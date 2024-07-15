part of "../../client.dart";

class WebsocketConnectionSettings implements BaseConnectionSettings{
  // The host to connect to
  @override
  String? host;

  // The port to connect to
  @override
  int? port;

  // The uri to connect to websocket. Use either host and url
  @override
  Uri? uri;

  // The connection vhost that will be sent to the server
  @override
  String virtualHost;

  // The max number of reconnection attempts before declaring a connection as unusable
  @override
  int maxConnectionAttempts;

  // The time to wait  before trying to reconnect
  @override
  Duration reconnectWaitTime;

  // Authentication provider
  @override
  Authenticator authProvider;

  // Protocol version
  @override
  int amqpProtocolVersion = 0;
  @override
  int amqpMajorVersion = 0;
  @override
  int amqpMinorVersion = 9;
  @override
  int amqpRevision = 1;

  // Tuning settings
  @override
  TuningSettings tuningSettings;

  // TLS settings (if TLS connection is required)
  @override
  SecurityContext? tlsContext;
  @override
  bool Function(X509Certificate)? onBadCertificate;

  // Connection identifier
  @override
  String? connectionName;

  // The time to wait for socket connection to be established
  @override
  Duration? connectTimeout;

  WebsocketConnectionSettings({
    this.uri,
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
