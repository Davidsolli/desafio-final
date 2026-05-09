import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omniconnect_fitness/screens/student/chat_screen.dart';
import 'package:omniconnect_fitness/theme/app_theme.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _NoopChannel implements WebSocketChannel {
  final _controller = StreamController<dynamic>.broadcast();
  final _sink = _NoopSink();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopSink implements WebSocketSink {
  @override
  void add(dynamic message) {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  Future addStream(Stream stream) async {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future get done => Completer<void>().future;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: child,
  );
}

const String _expectedDisclaimer =
    'Este assistente é informativo e não substitui a orientação do seu '
    'Personal Trainer ou Nutricionista.';

void main() {
  group('Card 19.9 — Aviso de responsabilidade', () {
    testWidgets('disclaimer is displayed in chat interface', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => _NoopChannel(), jwtToken: 'tok'),
      ));
      await tester.pump();

      expect(find.text(_expectedDisclaimer), findsOneWidget);
    });

    testWidgets('disclaimer appears on first message or start',
        (tester) async {
      // Mesmo antes da conexão WS estar autenticada, o aviso já está visível
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => _NoopChannel(), jwtToken: 'tok'),
      ));
      await tester.pump();

      expect(find.text(_expectedDisclaimer), findsOneWidget);
    });

    testWidgets('disclaimer text is clear and objective', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => _NoopChannel(), jwtToken: 'tok'),
      ));
      await tester.pump();

      final disclaimerFinder = find.text(_expectedDisclaimer);
      expect(disclaimerFinder, findsOneWidget);

      // Texto curto, objetivo e legível: máximo ~200 caracteres
      final widget = tester.widget<Text>(disclaimerFinder);
      expect(widget.data!.length, lessThan(200));
      expect(widget.data, contains('Personal Trainer'));
      expect(widget.data, contains('Nutricionista'));
    });

    testWidgets('disclaimer does not block user experience', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatScreen(channelFactory: (_) => _NoopChannel(), jwtToken: 'tok'),
      ));
      await tester.pump();

      // Input de mensagem continua existindo (não foi escondido pelo aviso)
      expect(find.byType(TextField), findsOneWidget);
      // Botão de enviar também
      expect(find.byIcon(Icons.send), findsOneWidget);
    });
  });
}
