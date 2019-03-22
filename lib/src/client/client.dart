part of dart_amqp.client;

abstract class Client {
  factory Client({ConnectionSettings settings}) =>
      _ClientImpl(settings: settings);

  // Configuration options
  ConnectionSettings get settings;
  TuningSettings get tuningSettings;

  /// Check if a connection is currently in handshake state
  bool get handshaking;

  /// Open a working connection to the server. Returns a [Future] to be completed on a successful protocol handshake

  Future connect();

  /// Shutdown any open channels and disconnect the socket. Return a [Future] to be completed
  /// when the client has shut down
  Future close();

  /// Allocate and initialize a new [Channel]. Return a [Future] to be completed with
  /// the new [Channel]
  Future<Channel> channel();

  /// Register listener for errors
  StreamSubscription<Exception> errorListener(void onData(Exception error),
      {Function onError, void onDone(), bool cancelOnError});
}
