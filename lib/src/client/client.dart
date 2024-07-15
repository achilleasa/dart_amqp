part of "../client.dart";

abstract class Client {
  factory Client({BaseConnectionSettings? settings}) =>
      _ClientImpl(settings: settings);

  // Configuration options
  BaseConnectionSettings get settings;
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
  StreamSubscription<Exception> errorListener(
      void Function(Exception error) onData,
      {Function onError,
      void Function() onDone,
      bool cancelOnError});
}
