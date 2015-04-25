part of dart_amqp.client;

abstract class Client {

  factory Client({ConnectionSettings settings}) => new _ClientImpl(settings : settings);

  // Configuration options
  ConnectionSettings get settings;
  TuningSettings get tuningSettings;

  /**
   * Check if a connection is currently in handshake state
   */
  bool get handshaking;

  /**
   * Open a working connection to the server using [config.cqlVersion] and optionally select
   * keyspace [defaultKeyspace]. Returns a [Future] to be completed on a successful protocol handshake
   */

  Future connect();

  /**
   * Shutdown any open channels and disconnect the socket. Return a [Future] to be completed
   * when the client has shut down
   */
  Future close();

  Future<Channel> channel();
}
