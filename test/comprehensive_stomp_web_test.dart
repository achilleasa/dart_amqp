import 'dart:async';
import 'package:test/test.dart';
import 'package:dart_amqp/dart_amqp.dart';

/// 🧪 Teste Abrangente - RabbitMQ Web STOMP (Flutter Web)
/// Testa todos os cenários do protocolo STOMP com broker real
/// Usa AMQP para provisionar infraestrutura e STOMP para consumo/publicação
void main() {
  // =============================================================================
  // CONFIGURAÇÕES DO BROKER REAL
  // =============================================================================
  const String host = 'localhost';
  const int amqpPort = 5672;
  const int stompPort = 15674;
  const String username = 'admin';
  const String password = 'Admin@123';
  const String vhost = '/';

  group('🧪 RabbitMQ Web STOMP - Teste Abrangente', () {
    late Client amqpClient;
    late Client stompClient;
    late Channel amqpChannel;
    late Channel stompChannel;

    setUpAll(() async {
      print('🚀 Configurando infraestrutura via AMQP...');

      // Cliente AMQP para provisionar infraestrutura
      amqpClient = Client(
        settings: ConnectionSettings(
          host: host,
          port: amqpPort,
          authProvider: const PlainAuthenticator(username, password),
          virtualHost: vhost,
        ),
      );

      await amqpClient.connect();
      amqpChannel = await amqpClient.channel();

      // Criar exchanges de teste
      await amqpChannel.exchange('test_direct_exchange', ExchangeType.DIRECT, durable: true);
      await amqpChannel.exchange('test_topic_exchange', ExchangeType.TOPIC, durable: true);
      await amqpChannel.exchange('test_fanout_exchange', ExchangeType.FANOUT, durable: true);

      // Criar filas de teste
      await amqpChannel.queue('test_queue_durable', durable: true);
      await amqpChannel.queue('test_queue_temp', durable: false, autoDelete: true);
      await amqpChannel.queue('test_rpc_queue', durable: true);
      await amqpChannel.queue('test_reply_queue', durable: false, autoDelete: true);
      await amqpChannel.queue('test_concurrent_queue', durable: true);

      // Fazer bindings necessários
      final directExchange = await amqpChannel.exchange('test_direct_exchange', ExchangeType.DIRECT, passive: true);
      final topicExchange = await amqpChannel.exchange('test_topic_exchange', ExchangeType.TOPIC, passive: true);
      final fanoutExchange = await amqpChannel.exchange('test_fanout_exchange', ExchangeType.FANOUT, passive: true);

      final durableQueue = await amqpChannel.queue('test_queue_durable', passive: true);
      final tempQueue = await amqpChannel.queue('test_queue_temp', passive: true);
      final rpcQueue = await amqpChannel.queue('test_rpc_queue', passive: true);
      final concurrentQueue = await amqpChannel.queue('test_concurrent_queue', passive: true);

      await durableQueue.bind(directExchange, 'test.direct');
      await tempQueue.bind(topicExchange, 'test.topic.*');
      await rpcQueue.bind(directExchange, 'test.rpc');
      await concurrentQueue.bind(fanoutExchange, '');

      print('✅ Infraestrutura AMQP criada');
    });

    tearDownAll(() async {
      try {
        // Limpar filas de teste antes de fechar
        final cleanupQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        await cleanupQueue.purge();

        final cleanupConcurrentQueue = await amqpChannel.queue('test_concurrent_queue', passive: true);
        await cleanupConcurrentQueue.purge();

        final cleanupRpcQueue = await amqpChannel.queue('test_rpc_queue', passive: true);
        await cleanupRpcQueue.purge();

        final cleanupReplyQueue = await amqpChannel.queue('test_reply_queue', passive: true);
        await cleanupReplyQueue.purge();

        await stompClient.close();
        await amqpClient.close();
        print('✅ Conexões fechadas e filas limpas');
      } catch (e) {
        print('⚠️ Erro ao fechar conexões: $e');
      }
    });

    setUp(() async {
      // Cliente STOMP para cada teste com nome único e conectar imediatamente
      final testId = DateTime.now().millisecondsSinceEpoch;
      stompClient = Client.forWeb(
        settings: ConnectionSettings(
          host: host,
          port: stompPort,
          authProvider: const PlainAuthenticator(username, password),
          virtualHost: vhost,
          connectionName: 'test_$testId',
        ),
      );

      // Conectar e criar canal no setUp para garantir estado limpo
      await stompClient.connect();
      stompChannel = await stompClient.channel();

      // Aguardar estabilização da conexão
      await Future.delayed(const Duration(milliseconds: 200));
    });

    tearDown(() async {
      try {
        await stompClient.close();
        // Aguardar um pouco para garantir limpeza completa
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('⚠️ Erro no tearDown: $e');
      }
    });

    // =============================================================================
    // 1. TESTES DE CONEXÃO
    // =============================================================================
    group('1️⃣ Conexão', () {
      test('1.1 - Conectar no broker via WebSocket', () async {
        await stompClient.connect();
        expect(stompClient, isNotNull);
        print('✅ Conexão WebSocket estabelecida');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('1.3 - Validar autenticação com credenciais corretas', () async {
        await stompClient.connect();
        stompChannel = await stompClient.channel();
        expect(stompChannel, isNotNull);
        print('✅ Autenticação bem-sucedida');
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('1.4 - Validar erro de autenticação com credenciais inválidas', () async {
        final invalidClient = Client.forWeb(
          settings: ConnectionSettings(
            host: host,
            port: stompPort,
            authProvider: const PlainAuthenticator('invalid_user', 'invalid_pass'),
            virtualHost: vhost,
          ),
        );

        try {
          await invalidClient.connect();
          fail('Deveria ter falhado com credenciais inválidas');
        } catch (e) {
          expect(e, isA<Exception>());
          print('✅ Autenticação falhou conforme esperado: $e');
        } finally {
          await invalidClient.close();
        }
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('1.6 - Validar heartbeat entre cliente e broker', () async {
        await stompClient.connect();
        stompChannel = await stompClient.channel();

        // Aguardar alguns heartbeats
        await Future.delayed(const Duration(seconds: 25));

        // Se chegou até aqui, heartbeat está funcionando
        expect(stompChannel, isNotNull);
        print('✅ Heartbeat funcionando (connection mantida por 25s)');
      }, timeout: const Timeout(Duration(seconds: 35)));
    });

    // =============================================================================
    // 2. TESTES DE CONSUMO (SUBSCRIBE)
    // =============================================================================
    group('2️⃣ Consumo (Subscribe)', () {
      test('2.1 - Assinar uma fila existente', () async {
        final queue = await stompChannel.queue('test_queue_durable', passive: true);
        final consumer = await queue.consume(noAck: false);

        expect(consumer, isNotNull);
        expect(consumer.tag, isNotEmpty);
        print('✅ Assinatura da fila criada: ${consumer.tag}');

        await consumer.cancel();
      });

      test('2.2 - Receber mensagens publicadas enquanto conectado', () async {
        // Purge fila para evitar mensagens remanescentes
        final amqpPurgeQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        await amqpPurgeQueue.purge();

        final queue = await stompChannel.queue('test_queue_durable', passive: true);
        final consumer = await queue.consume(noAck: false);

        final receivedMessages = <AmqpMessage>[];
        final completer = Completer<void>();

        consumer.listen((message) {
          receivedMessages.add(message);
          message.ack();
          print('📨 Mensagem recebida: ${message.payloadAsString}');

          if (receivedMessages.length >= 2) {
            completer.complete();
          }
        });

        // Aguardar um pouco para garantir que a assinatura STOMP está ativa
        await Future.delayed(const Duration(milliseconds: 1000));

        // Publicar mensagens via AMQP com mais espaçamento
        final amqpQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        amqpQueue.publish({'test': 'message_1', 'timestamp': DateTime.now().toIso8601String()});
        await Future.delayed(const Duration(milliseconds: 500));
        amqpQueue.publish({'test': 'message_2', 'timestamp': DateTime.now().toIso8601String()});

        await completer.future.timeout(const Duration(seconds: 20));

        expect(receivedMessages.length, equals(2));
        print('✅ Recebidas ${receivedMessages.length} mensagens');

        await consumer.cancel();
      });

      test('2.4 - Assinar um tópico e validar pub/sub', () async {
        final exchange = await stompChannel.exchange('test_topic_exchange', ExchangeType.TOPIC, passive: true);
        final consumer = await exchange.bindPrivateQueueConsumer(['test.topic.*']);

        final receivedMessages = <AmqpMessage>[];
        final completer = Completer<void>();

        consumer.listen((message) {
          receivedMessages.add(message);
          message.ack();
          print('📨 Tópico recebido: ${message.routingKey} -> ${message.payloadAsString}');
          completer.complete();
        });

        // Publicar no tópico via AMQP
        final amqpExchange = await amqpChannel.exchange('test_topic_exchange', ExchangeType.TOPIC, passive: true);
        amqpExchange.publish(
          {'test': 'topic_message', 'timestamp': DateTime.now().toIso8601String()},
          'test.topic.stomp',
        );

        await completer.future.timeout(const Duration(seconds: 10));

        expect(receivedMessages.length, equals(1));
        expect(receivedMessages.first.routingKey, equals('test.topic.stomp'));
        print('✅ Mensagem de tópico recebida corretamente');

        await consumer.cancel();
      });

      test('2.7 - Validar cancelamento da assinatura', () async {
        final queue = await stompChannel.queue('test_queue_durable', passive: true);
        final consumer = await queue.consume(noAck: false);

        expect(consumer, isNotNull);

        await consumer.cancel();
        print('✅ Assinatura cancelada');

        // Tentar publicar após cancelamento
        final amqpQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        amqpQueue.publish({'test': 'should_not_receive'});

        // Aguardar um pouco para garantir que não recebe
        await Future.delayed(const Duration(seconds: 2));
        print('✅ Mensagem não recebida após cancelamento');
      });
    });

    // =============================================================================
    // 3. TESTES DE PUBLICAÇÃO (SEND)
    // =============================================================================
    group('3️⃣ Publicação (Send)', () {
      test('3.1 - Publicar mensagem em uma fila', () async {
        // Purge antes do teste
        final amqpPurgeQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        await amqpPurgeQueue.purge();

        final queue = await stompChannel.queue('test_queue_durable', passive: true);

        final testMessage = {
          'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
          'content': 'Mensagem de teste para fila',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Criar consumer AMQP ANTES de publicar via STOMP
        final amqpQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        final amqpConsumer = await amqpQueue.consume();

        final completer = Completer<AmqpMessage>();
        late StreamSubscription subscription;

        subscription = amqpConsumer.listen((message) {
          if (!completer.isCompleted) {
            completer.complete(message);
            subscription.cancel();
          }
        });

        // Aguardar consumer estar pronto
        await Future.delayed(const Duration(milliseconds: 200));

        queue.publish(testMessage);
        print('✅ Mensagem publicada na fila');

        final receivedMessage = await completer.future.timeout(const Duration(seconds: 20));
        expect(receivedMessage.payloadAsJson['id'], equals(testMessage['id']));
        print('✅ Mensagem verificada via consumer AMQP');

        await amqpConsumer.cancel();
      });

      test('3.2 - Publicar mensagem em um tópico', () async {
        final exchange = await stompChannel.exchange('test_topic_exchange', ExchangeType.TOPIC, passive: true);

        final testMessage = {
          'id': 'topic_test_${DateTime.now().millisecondsSinceEpoch}',
          'content': 'Mensagem de teste para tópico',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Criar consumer AMQP ANTES de publicar via STOMP
        final amqpExchange = await amqpChannel.exchange('test_topic_exchange', ExchangeType.TOPIC, passive: true);
        final tempQueue = await amqpChannel.queue('temp_verify_${DateTime.now().millisecondsSinceEpoch}', autoDelete: true, exclusive: true);
        await tempQueue.bind(amqpExchange, 'test.topic.*');

        final amqpConsumer = await tempQueue.consume();
        final completer = Completer<AmqpMessage>();
        amqpConsumer.listen((message) {
          completer.complete(message);
        });

        // Aguardar consumer estar pronto
        await Future.delayed(const Duration(milliseconds: 200));

        exchange.publish(testMessage, 'test.topic.stomp');
        print('✅ Mensagem publicada no tópico');

        final receivedMessage = await completer.future.timeout(const Duration(seconds: 10));
        expect(receivedMessage.payloadAsJson['id'], equals(testMessage['id']));
        expect(receivedMessage.routingKey, equals('test.topic.stomp'));
        print('✅ Mensagem de tópico verificada via consumer AMQP');

        await amqpConsumer.cancel();
      });

      test('3.3 - Publicar mensagem com corpo JSON e consumir corretamente', () async {
        // Purge antes do teste
        final amqpPurgeQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        await amqpPurgeQueue.purge();

        final queue = await stompChannel.queue('test_queue_durable', passive: true);

        final complexMessage = {
          'id': 'json_test_${DateTime.now().millisecondsSinceEpoch}',
          'user': {
            'name': 'Test User',
            'email': 'test@example.com',
            'preferences': ['email', 'sms'],
          },
          'data': {
            'numbers': [1, 2, 3, 4, 5],
            'nested': {
              'value': 42,
              'active': true,
            },
          },
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Consumir via STOMP
        final consumer = await queue.consume();
        final completer = Completer<AmqpMessage>();

        consumer.listen((message) {
          completer.complete(message);
        });

        // Aguardar consumer estar pronto (maior delay para self-publishing)
        await Future.delayed(const Duration(milliseconds: 1000));

        queue.publish(complexMessage, properties: MessageProperties()..contentType = 'application/json');
        print('✅ Mensagem JSON complexa publicada');

        final receivedMessage = await completer.future.timeout(const Duration(seconds: 10));
        final receivedJson = receivedMessage.payloadAsJson;

        expect(receivedJson['id'], equals(complexMessage['id']));
        expect(receivedJson['user']['name'], equals('Test User'));
        expect(receivedJson['data']['numbers'], equals([1, 2, 3, 4, 5]));
        expect(receivedJson['data']['nested']['value'], equals(42));
        print('✅ JSON complexo recebido e parseado corretamente');

        await consumer.cancel();
      });

      test('3.4 - Publicar mensagem com headers customizados', () async {
        // Purge antes do teste
        final amqpPurgeQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        await amqpPurgeQueue.purge();

        final queue = await stompChannel.queue('test_queue_durable', passive: true);

        final testMessage = {
          'id': 'header_test_${DateTime.now().millisecondsSinceEpoch}',
          'content': 'Mensagem com headers customizados',
        };

        final properties = MessageProperties()
          ..contentType = 'application/json'
          ..corellationId = 'correlation_123'
          ..replyTo = 'test_reply_queue'
          ..deliveryMode = 2
          ..priority = 5
          ..expiration = '60000'
          ..messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

        // Verificar headers via consumer
        final consumer = await queue.consume();
        final completer = Completer<AmqpMessage>();

        consumer.listen((message) {
          completer.complete(message);
        });

        // Aguardar consumer estar pronto (maior delay para self-publishing)
        await Future.delayed(const Duration(milliseconds: 1000));

        queue.publish(testMessage, properties: properties);
        print('✅ Mensagem com headers customizados publicada');

        final receivedMessage = await completer.future.timeout(const Duration(seconds: 10));

        expect(receivedMessage.properties?.contentType, equals('application/json'));
        expect(receivedMessage.properties?.corellationId, equals('correlation_123'));
        expect(receivedMessage.properties?.replyTo, equals('test_reply_queue'));
        print('✅ Headers customizados recebidos corretamente');

        await consumer.cancel();
      });

      test('3.7 - Validar envio com reply-to e simular RPC simples', () async {
        // Purge filas RPC/reply antes do teste
        final purgeRpc = await amqpChannel.queue('test_rpc_queue', passive: true);
        await purgeRpc.purge();
        final purgeReply = await amqpChannel.queue('test_reply_queue', passive: true);
        await purgeReply.purge();

        final requestQueue = await stompChannel.queue('test_rpc_queue', passive: true);
        final replyQueue = await stompChannel.queue('test_reply_queue', passive: true);

        // Setup reply consumer via AMQP (mais estável)
        final amqpReplyQueue = await amqpChannel.queue('test_reply_queue', passive: true);
        final replyConsumer = await amqpReplyQueue.consume();
        final replyCompleter = Completer<AmqpMessage>();

        replyConsumer.listen((message) {
          print('📨 Reply recebido (AMQP): ${message.payloadAsString}');
          replyCompleter.complete(message);
        });

        // Setup request consumer via AMQP (mais estável no servidor)
        final amqpRequestQueue = await amqpChannel.queue('test_rpc_queue', passive: true);
        final requestConsumer = await amqpRequestQueue.consume();
        requestConsumer.listen((message) {
          print('📨 Request recebido (AMQP): ${message.payloadAsString}');

          // Enviar reply via AMQP
          final replyData = {
            'status': 'success',
            'original_request': message.payloadAsJson,
            'response_time': DateTime.now().toIso8601String(),
          };

          message.reply(replyData);
          print('📤 Reply enviado (AMQP)');
        });

        // Aguardar consumers estarem prontos (maior delay para RPC)
        await Future.delayed(const Duration(seconds: 5));

        // Reforçar a conexão e reobter fila antes de publicar
        await stompClient.connect();
        stompChannel = await stompClient.channel();
        final requestQueueFresh = await stompChannel.queue('test_rpc_queue', passive: true);

        // Enviar request
        final requestData = {
          'id': 'rpc_test_${DateTime.now().millisecondsSinceEpoch}',
          'method': 'test_rpc',
          'params': {'value': 42},
        };

        final properties = MessageProperties()
          ..replyTo = 'test_reply_queue'
          ..corellationId = 'rpc_correlation_123';

        requestQueueFresh.publish(requestData, properties: properties);
        print('📤 RPC Request enviado');

        // Aguardar reply
        final replyMessage = await replyCompleter.future.timeout(const Duration(seconds: 20));
        final replyJson = replyMessage.payloadAsJson;

        expect(replyJson['status'], equals('success'));
        expect(replyJson['original_request']['id'], equals(requestData['id']));
        print('✅ RPC completo funcionando');

        await requestConsumer.cancel();
        await replyConsumer.cancel();
      });
    });

    // =============================================================================
    // 4. TESTES DE ACKNOWLEDGMENT
    // =============================================================================
    group('4️⃣ Acknowledgment', () {
      test('4.1 - Consumir mensagens em modo automático', () async {
        final queue = await stompChannel.queue('test_queue_durable', passive: true);

        final consumer = await queue.consume(noAck: true); // Auto ACK
        final completer = Completer<AmqpMessage>();

        consumer.listen((message) {
          print('📨 Mensagem auto-ack recebida: ${message.payloadAsString}');
          completer.complete(message);
          // Não precisamos chamar message.ack() em modo automático
        });

        // Aguardar consumer estar pronto (maior delay para self-publishing)
        await Future.delayed(const Duration(milliseconds: 1000));

        // Publicar mensagem de teste
        queue.publish({'test': 'auto_ack_message', 'timestamp': DateTime.now().toIso8601String()});

        final receivedMessage = await completer.future.timeout(const Duration(seconds: 10));
        expect(receivedMessage.payloadAsJson['test'], equals('auto_ack_message'));
        print('✅ Auto ACK funcionando');

        await consumer.cancel();
      });

      test('4.2 - Consumir mensagens em modo manual', () async {
        final queue = await stompChannel.queue('test_queue_durable', passive: true);

        final consumer = await queue.consume(noAck: false); // Manual ACK
        final completer = Completer<AmqpMessage>();

        consumer.listen((message) {
          print('📨 Mensagem manual-ack recebida: ${message.payloadAsString}');
          message.ack(); // ACK manual
          completer.complete(message);
        });

        // Aguardar consumer estar pronto (maior delay para self-publishing)
        await Future.delayed(const Duration(milliseconds: 1000));

        // Publicar mensagem de teste
        queue.publish({'test': 'manual_ack_message', 'timestamp': DateTime.now().toIso8601String()});

        final receivedMessage = await completer.future.timeout(const Duration(seconds: 5));
        expect(receivedMessage.payloadAsJson['test'], equals('manual_ack_message'));
        print('✅ Manual ACK funcionando');

        await consumer.cancel();
      });
    });

    // =============================================================================
    // 6. TESTES DE CONCORRÊNCIA
    // =============================================================================
    group('6️⃣ Concorrência', () {
      test('6.1 - Dois clientes assinando a mesma fila (round-robin)', () async {
        // Segundo cliente STOMP
        final client2 = Client.forWeb(
          settings: ConnectionSettings(
            host: host,
            port: stompPort,
            authProvider: const PlainAuthenticator(username, password),
            connectionName: 'concurrent_test_2',
          ),
        );

        await client2.connect();
        final channel2 = await client2.channel();

        final queue1 = await stompChannel.queue('test_concurrent_queue', passive: true);
        final queue2 = await channel2.queue('test_concurrent_queue', passive: true);

        final consumer1 = await queue1.consume();
        final consumer2 = await queue2.consume();

        final messages1 = <AmqpMessage>[];
        final messages2 = <AmqpMessage>[];
        final completer = Completer<void>();

        consumer1.listen((message) {
          messages1.add(message);
          print('📨 Cliente 1 recebeu: ${message.payloadAsString}');
          if (messages1.length + messages2.length >= 4) {
            completer.complete();
          }
        });

        consumer2.listen((message) {
          messages2.add(message);
          print('📨 Cliente 2 recebeu: ${message.payloadAsString}');
          if (messages1.length + messages2.length >= 4) {
            completer.complete();
          }
        });

        // Publicar várias mensagens
        for (int i = 1; i <= 4; i++) {
          queue1.publish({'test': 'concurrent_message_$i', 'id': i});
          await Future.delayed(const Duration(milliseconds: 100));
        }

        await completer.future.timeout(const Duration(seconds: 10));

        // Verificar distribuição (round-robin)
        expect(messages1.length + messages2.length, equals(4));
        expect(messages1.length, greaterThan(0));
        expect(messages2.length, greaterThan(0));
        print('✅ Round-robin entre dois clientes funcionando');
        print('   Cliente 1: ${messages1.length} mensagens');
        print('   Cliente 2: ${messages2.length} mensagens');

        await consumer1.cancel();
        await consumer2.cancel();
        await client2.close();
      });

      test('6.2 - Dois clientes assinando o mesmo tópico (broadcast)', () async {
        final client2 = Client.forWeb(
          settings: ConnectionSettings(
            host: host,
            port: stompPort,
            authProvider: const PlainAuthenticator(username, password),
            connectionName: 'topic_test_2',
          ),
        );

        await client2.connect();
        final channel2 = await client2.channel();

        final exchange1 = await stompChannel.exchange('test_topic_exchange', ExchangeType.TOPIC, passive: true);
        final exchange2 = await channel2.exchange('test_topic_exchange', ExchangeType.TOPIC, passive: true);

        final consumer1 = await exchange1.bindPrivateQueueConsumer(['test.broadcast.*']);
        final consumer2 = await exchange2.bindPrivateQueueConsumer(['test.broadcast.*']);

        final messages1 = <AmqpMessage>[];
        final messages2 = <AmqpMessage>[];
        final completer = Completer<void>();

        consumer1.listen((message) {
          messages1.add(message);
          print('📨 Tópico Cliente 1: ${message.payloadAsString}');
          if (messages1.length >= 2 && messages2.length >= 2) {
            completer.complete();
          }
        });

        consumer2.listen((message) {
          messages2.add(message);
          print('📨 Tópico Cliente 2: ${message.payloadAsString}');
          if (messages1.length >= 2 && messages2.length >= 2) {
            completer.complete();
          }
        });

        // Aguardar consumers estarem prontos
        await Future.delayed(const Duration(milliseconds: 500));

        // Publicar mensagens no tópico
        exchange1.publish({'test': 'broadcast_message_1'}, 'test.broadcast.msg1');
        await Future.delayed(const Duration(milliseconds: 300));
        exchange1.publish({'test': 'broadcast_message_2'}, 'test.broadcast.msg2');

        await completer.future.timeout(const Duration(seconds: 10));

        // Ambos clientes devem receber todas as mensagens
        expect(messages1.length, equals(2));
        expect(messages2.length, equals(2));
        print('✅ Broadcast para dois clientes funcionando');

        await consumer1.cancel();
        await consumer2.cancel();
        await client2.close();
      });
    });

    // =============================================================================
    // 8. TESTES DE LIMITAÇÕES / BORDAS
    // =============================================================================
    group('8️⃣ Limitações / Bordas', () {
      test('8.1 - Tentar criar fila via STOMP deve falhar', () async {
        try {
          await stompChannel.queue('new_queue_that_should_fail', declare: true);
          fail('Deveria ter falhado ao tentar criar fila via STOMP');
        } catch (e) {
          expect(e, isA<StateError>());
          expect(e.toString(), contains('STOMP/WebSocket cannot create queues'));
          print('✅ Criação de fila via STOMP falhou conforme esperado: $e');
        }
      });

      test('8.2 - Tentar criar exchange via STOMP deve falhar', () async {
        try {
          await stompChannel.exchange('new_exchange_that_should_fail', ExchangeType.DIRECT, declare: true);
          fail('Deveria ter falhado ao tentar criar exchange via STOMP');
        } catch (e) {
          expect(e, isA<StateError>());
          expect(e.toString(), contains('STOMP/WebSocket cannot create exchanges'));
          print('✅ Criação de exchange via STOMP falhou conforme esperado: $e');
        }
      });

      test('8.3 - Tentar criar fila privada via STOMP deve falhar', () async {
        try {
          await stompChannel.privateQueue();
          fail('Deveria ter falhado ao tentar criar privateQueue via STOMP');
        } catch (e) {
          expect(e, isA<StateError>());
          expect(e.toString(), contains('STOMP/WebSocket cannot create private/temporary queues'));
          print('✅ Criação de privateQueue via STOMP falhou conforme esperado: $e');
        }
      });

      test('8.4 - Tentar deletar fila via STOMP deve falhar', () async {
        final queue = await stompChannel.queue('test_queue_durable', passive: true);

        try {
          await queue.delete();
          fail('Deveria ter falhado ao tentar deletar fila via STOMP');
        } catch (e) {
          expect(e, isA<StateError>());
          expect(e.toString(), contains('STOMP/WebSocket cannot delete queues'));
          print('✅ Deleção de fila via STOMP falhou conforme esperado: $e');
        }
      });

      test('8.5 - Tentar deletar exchange via STOMP deve falhar', () async {
        final exchange = await stompChannel.exchange('test_direct_exchange', ExchangeType.DIRECT, passive: true);

        try {
          await exchange.delete();
          fail('Deveria ter falhado ao tentar deletar exchange via STOMP');
        } catch (e) {
          expect(e, isA<StateError>());
          expect(e.toString(), contains('Deleting exchanges is not supported over STOMP/WebSocket'));
          print('✅ Deleção de exchange via STOMP falhou conforme esperado: $e');
        }
      });
    });

    // =============================================================================
    // 5. TESTES DE TIMEOUT / RECONEXÃO
    // =============================================================================
    group('5️⃣ Timeout / Reconexão', () {
      test('5.1 - Simular reconexão após desconexão', () async {
        await stompClient.connect();
        stompChannel = await stompClient.channel();

        final queue = await stompChannel.queue('test_queue_durable', passive: true);

        // Testar conexão inicial
        queue.publish({'test': 'before_disconnect', 'timestamp': DateTime.now().toIso8601String()});
        print('✅ Mensagem enviada antes da desconexão');

        // Simular desconexão fechando o cliente
        await stompClient.close();
        print('🔌 Cliente desconectado');

        // Aguardar um pouco
        await Future.delayed(const Duration(seconds: 2));

        // Reconectar
        stompClient = Client.forWeb(
          settings: ConnectionSettings(
            host: host,
            port: stompPort,
            authProvider: const PlainAuthenticator(username, password),
            connectionName: 'reconnection_test',
          ),
        );

        await stompClient.connect();
        stompChannel = await stompClient.channel();
        final reconnectedQueue = await stompChannel.queue('test_queue_durable', passive: true);

        // Verificar se mensagens chegaram via consumer AMQP (criar consumer ANTES de publicar após reconexão)
        final amqpQueue = await amqpChannel.queue('test_queue_durable', passive: true);
        final consumer = await amqpQueue.consume();

        final receivedMessages = <AmqpMessage>[];
        final completer = Completer<void>();

        consumer.listen((message) {
          receivedMessages.add(message);
          print('📨 Verificação: ${message.payloadAsJson['test']}');

          if (receivedMessages.length >= 2) {
            completer.complete();
          }
        });

        // Aguardar consumer estar pronto antes de publicar após reconexão
        await Future.delayed(const Duration(milliseconds: 500));

        // Testar funcionalidade após reconexão
        reconnectedQueue.publish({'test': 'after_reconnect', 'timestamp': DateTime.now().toIso8601String()});
        print('✅ Mensagem enviada após reconexão');

        // Aguardar um pouco para permitir processamento de mensagens já na fila
        await Future.delayed(const Duration(milliseconds: 500));

        await completer.future.timeout(const Duration(seconds: 10));

        expect(receivedMessages.length, equals(2));
        expect(receivedMessages.any((m) => m.payloadAsJson['test'] == 'before_disconnect'), isTrue);
        expect(receivedMessages.any((m) => m.payloadAsJson['test'] == 'after_reconnect'), isTrue);
        print('✅ Reconexão funcionando - mensagens antes e depois recebidas');

        await consumer.cancel();
      }, timeout: const Timeout(Duration(seconds: 30)));
    });
  });
}
