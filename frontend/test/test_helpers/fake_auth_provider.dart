// ignore_for_file: type=lint
import 'package:mockito/mockito.dart';
import 'package:omniconnect_fitness/providers/auth_provider.dart';
import 'package:omniconnect_fitness/services/auth_service.dart';

class _FakeAuthService extends Fake implements AuthService {}

/// AuthProvider falso que não depende de AuthService — apenas devolve o
/// `user` configurado diretamente. Usado nos testes do dispatcher
/// `notifications_settings_screen.dart` (Fase 4) onde o único campo
/// realmente lido é `user.role`.
class FakeAuthProvider extends AuthProvider {
  final AuthUser? _userOverride;

  FakeAuthProvider({AuthUser? user})
      : _userOverride = user,
        super(authService: _FakeAuthService());

  @override
  AuthUser? get user => _userOverride;
}
