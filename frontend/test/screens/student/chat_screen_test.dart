import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/screens/student/chat_screen.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Fake `WebSocketChannel` para testes de widget.
///
/// Permite que o teste:
/// - Capture mensagens enviadas pelo cliente (`sentMessages`).
/// - Empurre eventos JSON ao cliente (`pushFromServer`).
class FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _serverToClient =
      StreamController<dynamic>.broadcast();
  final List<String> sentMessages = [];

  @override
  Stream<dynamic> get stream => _serverToClient.stream;

  @override
  WebSocketSink get sink => _FakeSink(sentMessages, _serverToClient);

  void pushFromServer(String json) => _serverToClient.add(json);

  @override
  // ignore: invalid_use_of_visible_for_testing_member
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  final List<String> _sent;
  final StreamController _controller;

  _FakeSink(this._sent, this._controller);

  @override
  void add(dynamic message) {
    if (message is String) _sent.add(message);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future addStream(Stream stream) async {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future get done => _controller.done;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: child,
  );
}

void main() {
  group('Card 18.7 — Tela de chatbot no app', () {
    testWidgets('chat screen exists and renders', (tester) async {
      final fake = FakeWebSocketChannel();
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => fake),
      ));
      await tester.pump();

      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('user can type and send message', (tester) async {
      final fake = FakeWebSocketChannel();
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => fake, jwtToken: 'fake-token'),
      ));
      await tester.pump();

      // Simula auth_success do servidor para habilitar envio
      fake.pushFromServer('{"type":"auth_success","message":"ok"}');
      await tester.pump(const Duration(milliseconds: 200));

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Como faço supino?');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Mensagem do aluno foi exibida no chat
      expect(find.text('Como faço supino?'), findsOneWidget);
      // E enviada pelo socket
      expect(
        fake.sentMessages.any((m) => m.contains('Como faço supino?')),
        isTrue,
      );
    });

    testWidgets('ai responses displayed in chat format', (tester) async {
      final fake = FakeWebSocketChannel();
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => fake, jwtToken: 'fake-token'),
      ));
      await tester.pump();

      fake.pushFromServer('{"type":"auth_success","message":"ok"}');
      await tester.pump(const Duration(milliseconds: 200));

      fake.pushFromServer(
        '{"type":"response","content":"Mantenha as escápulas retraídas",'
        '"message_id":"m1","conversation_id":"c1","latency_ms":800,'
        '"created_at":"2026-05-09T10:00:01Z"}',
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Mantenha as escápulas retraídas'), findsOneWidget);
    });

    testWidgets('message history maintained during session', (tester) async {
      final fake = FakeWebSocketChannel();
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => fake, jwtToken: 'fake-token'),
      ));
      await tester.pump();

      fake.pushFromServer('{"type":"auth_success","message":"ok"}');
      await tester.pump(const Duration(milliseconds: 200));

      // Primeira pergunta + resposta
      await tester.enterText(find.byType(TextField), 'Pergunta 1');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      fake.pushFromServer(
        '{"type":"response","content":"Resposta 1",'
        '"message_id":"m1","conversation_id":"c1"}',
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Segunda pergunta + resposta
      await tester.enterText(find.byType(TextField), 'Pergunta 2');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      fake.pushFromServer(
        '{"type":"response","content":"Resposta 2",'
        '"message_id":"m2","conversation_id":"c1"}',
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Ambas as perguntas e respostas continuam no histórico em memória
      expect(find.text('Pergunta 1'), findsOneWidget);
      expect(find.text('Resposta 1'), findsOneWidget);
      expect(find.text('Pergunta 2'), findsOneWidget);
      expect(find.text('Resposta 2'), findsOneWidget);
    });

    testWidgets('loading indicator shown while ai responds', (tester) async {
      final fake = FakeWebSocketChannel();
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => fake, jwtToken: 'fake-token'),
      ));
      await tester.pump();

      fake.pushFromServer('{"type":"auth_success","message":"ok"}');
      await tester.pump(const Duration(milliseconds: 200));

      // Servidor envia status intermediários
      fake.pushFromServer(
        '{"type":"status","status":"thinking",'
        '"message":"Analisando sua pergunta..."}',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Analisando sua pergunta...'), findsOneWidget);

      fake.pushFromServer(
        '{"type":"status","status":"searching",'
        '"message":"Buscando na base de conhecimento..."}',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Buscando na base de conhecimento...'), findsOneWidget);

      fake.pushFromServer(
        '{"type":"status","status":"generating",'
        '"message":"Preparando sua resposta..."}',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Preparando sua resposta...'), findsOneWidget);

      // Indicador some quando a resposta chega
      fake.pushFromServer(
        '{"type":"response","content":"OK","message_id":"m1","conversation_id":"c1"}',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Preparando sua resposta...'), findsNothing);
    });

    testWidgets('user and bot messages visually distinct', (tester) async {
      final fake = FakeWebSocketChannel();
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => fake, jwtToken: 'fake-token'),
      ));
      await tester.pump();

      fake.pushFromServer('{"type":"auth_success","message":"ok"}');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), 'Pergunta');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      fake.pushFromServer(
        '{"type":"response","content":"Resposta do bot",'
        '"message_id":"m1","conversation_id":"c1"}',
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Usuário alinha à direita, bot à esquerda
      final userAlign = tester.widget<Align>(
        find.ancestor(of: find.text('Pergunta'), matching: find.byType(Align)),
      );
      final botAlign = tester.widget<Align>(
        find.ancestor(
          of: find.text('Resposta do bot'),
          matching: find.byType(Align),
        ),
      );
      expect(userAlign.alignment, Alignment.centerRight);
      expect(botAlign.alignment, Alignment.centerLeft);
    });

    testWidgets('layout is responsive', (tester) async {
      final fake = FakeWebSocketChannel();
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => fake, jwtToken: 'fake-token'),
      ));
      await tester.pump();

      fake.pushFromServer('{"type":"auth_success","message":"ok"}');
      await tester.pump(const Duration(milliseconds: 200));

      // Não deve estourar — sem RenderFlex overflow
      expect(tester.takeException(), isNull);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });

    testWidgets('screen consumes chatbot endpoint correctly', (tester) async {
      Uri? requestedUri;
      final fake = FakeWebSocketChannel();
      await tester.pumpWidget(_wrap(
        ChatScreen(
          channelFactory: (uri) {
            requestedUri = uri;
            return fake;
          },
          jwtToken: 'fake-token',
        ),
      ));
      await tester.pump();

      // Conexão tenta o caminho /api/v1/chat/ws
      expect(requestedUri, isNotNull);
      expect(requestedUri!.path, contains('/api/v1/chat/ws'));

      // E o cliente envia pacote de auth assim que conecta
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        fake.sentMessages.any((m) => m.contains('"type":"auth"')),
        isTrue,
      );
    });

    testWidgets('auto-scrolls when new message arrives', (tester) async {
      final fake = FakeWebSocketChannel();
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => fake, jwtToken: 'fake-token'),
      ));
      await tester.pump();

      fake.pushFromServer('{"type":"auth_success","message":"ok"}');
      await tester.pump(const Duration(milliseconds: 200));

      // Empurra muitas mensagens para forçar overflow do ListView
      for (int i = 0; i < 20; i++) {
        fake.pushFromServer(
          '{"type":"response","content":"Mensagem $i",'
          '"message_id":"m$i","conversation_id":"c1"}',
        );
        await tester.pump();
      }
      // pumpAndSettle para esperar a animação do auto-scroll
      await tester.pumpAndSettle();

      // A última mensagem deve estar visível (auto-scroll para o fim)
      expect(find.text('Mensagem 19'), findsOneWidget);
    });
  });
}
