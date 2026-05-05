import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/invitation_provider.dart';

class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({Key? key}) : super(key: key);

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _codeController = TextEditingController();
  bool _isValidating = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleValidate() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      _showError('Digite um código de convite');
      return;
    }

    if (code.length < 3) {
      _showError('Código inválido');
      return;
    }

    try {
      setState(() => _isValidating = true);

      final invitationProvider = context.read<InvitationProvider>();
      final isValid = await invitationProvider.validateCode(code);

      if (mounted) {
        if (isValid) {
          // Navega para registro passando o código
          context.go(
            AppRoutes.register,
            extra: {'invitationCode': code},
          );
        } else {
          _showError(invitationProvider.validationError ?? 'Código inválido');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar com botão voltar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go(AppRoutes.login),
                ),
              ),
            ),
            // Conteúdo principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ícone
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.card_giftcard_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Título
                    Text(
                      'Tem um código de acesso?',
                      style: Theme.of(context).textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Subtítulo
                    Text(
                      'Digite o código enviado pelo seu personal trainer para se cadastrar',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Campo de entrada
                    TextField(
                      controller: _codeController,
                      enabled: !_isValidating,
                      decoration: InputDecoration(
                        labelText: 'Código de Convite',
                        hintText: 'Ex: AB3X7KP2QR',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        errorText: _codeController.text.isEmpty ? null : '',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 32),
                    // Botão validar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isValidating ? null : _handleValidate,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                        ),
                        child: _isValidating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                'Validar Código',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
