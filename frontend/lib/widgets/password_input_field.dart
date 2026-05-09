import 'package:flutter/material.dart';

/// Componente reutilizável para input de senha com toggle de visualização
///
/// Funcionalidades:
/// - Toggle visualizar/ocultar senha
/// - Indicador visual de força de senha (opcional)
/// - Validação customizável
/// - Callback ao mudar visibilidade
/// - Suporte a tema claro/escuro
class PasswordInputField extends StatefulWidget {
  /// Controlador de texto
  final TextEditingController controller;

  /// Label do campo
  final String label;

  /// Texto de dica (hint text)
  final String? hintText;

  /// Ícone prefixo
  final IconData prefixIcon;

  /// Mostrar indicador de força de senha
  final bool showStrengthIndicator;

  /// Callback chamado quando força de senha muda (para cálculos em tempo real)
  final Function(PasswordStrength)? onStrengthChanged;

  /// Callback chamado quando Enter é pressionado
  final VoidCallback? onSubmitted;

  /// Desabilitar campo
  final bool enabled;

  /// Cores do tema
  final Color? primaryColor;
  final Color? backgroundColor;
  final Color? textSecondaryColor;

  /// Flag: é campo de confirmação (sem indicador de força)
  final bool isConfirmation;

  /// Descrição de requisitos de força
  final String? strengthDescription;

  const PasswordInputField({
    Key? key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon = Icons.lock_outline,
    this.showStrengthIndicator = false,
    this.onStrengthChanged,
    this.onSubmitted,
    this.enabled = true,
    this.primaryColor,
    this.backgroundColor,
    this.textSecondaryColor,
    this.isConfirmation = false,
    this.strengthDescription,
  }) : super(key: key);

  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = true;
    widget.controller.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPasswordChanged);
    super.dispose();
  }

  void _onPasswordChanged() {
    if (widget.showStrengthIndicator && !widget.isConfirmation) {
      final strength = _calculatePasswordStrength(widget.controller.text);
      widget.onStrengthChanged?.call(strength);
    }
  }

  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.empty;

    int score = 0;

    // Verificar requisitos
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'\d'))) score++;
    if (password.contains(RegExp(r'[@$!%*?&_\-]'))) score++;

    // Pontos adicionais por comprimento
    if (password.length > 12) score++;

    if (score <= 1) return PasswordStrength.weak;
    if (score <= 3) return PasswordStrength.fair;
    if (score <= 4) return PasswordStrength.good;
    return PasswordStrength.strong;
  }

  bool _isPasswordStrong(String password) {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_\-])[a-zA-Z\d@$!%*?&_\-]{8,}$',
    );
    return regex.hasMatch(password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = widget.primaryColor ?? theme.primaryColor;
    final backgroundColor = widget.backgroundColor ??
        (isDark ? theme.scaffoldBackgroundColor : Colors.grey[50]);
    final textSecondaryColor = widget.textSecondaryColor ??
        (isDark ? Colors.grey[400] : Colors.grey[600]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de senha com toggle
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscureText,
          onSubmitted: (_) => widget.onSubmitted?.call(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText ?? 'Digite sua senha',
            prefixIcon: Icon(widget.prefixIcon),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off : Icons.visibility,
                color: _obscureText ? Colors.grey : primaryColor,
              ),
              onPressed: widget.enabled
                  ? () {
                      setState(() => _obscureText = !_obscureText);
                    }
                  : null,
              tooltip:
                  _obscureText ? 'Mostrar senha' : 'Ocultar senha',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: primaryColor,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
            filled: true,
            fillColor: backgroundColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),

        // Indicador de força (se habilitado e não é campo de confirmação)
        if (widget.showStrengthIndicator && !widget.isConfirmation)
          _buildStrengthIndicator(
            widget.controller.text,
            primaryColor,
            isDark,
            textSecondaryColor!,
          ),

        // Descrição de requisitos
        if (widget.strengthDescription != null && widget.showStrengthIndicator && !widget.isConfirmation)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              widget.strengthDescription!,
              style: TextStyle(
                fontSize: 12,
                color: textSecondaryColor,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStrengthIndicator(
    String password,
    Color primaryColor,
    bool isDark,
    Color textSecondaryColor,
  ) {
    final strength = _calculatePasswordStrength(password);
    final isStrong = _isPasswordStrong(password);

    Color getStrengthColor() {
      switch (strength) {
        case PasswordStrength.empty:
          return Colors.grey;
        case PasswordStrength.weak:
          return Colors.red;
        case PasswordStrength.fair:
          return Colors.orange;
        case PasswordStrength.good:
          return Colors.yellow[700]!;
        case PasswordStrength.strong:
          return Colors.green;
      }
    }

    String getStrengthLabel() {
      switch (strength) {
        case PasswordStrength.empty:
          return 'Digite uma senha';
        case PasswordStrength.weak:
          return '✗ Muito fraca';
        case PasswordStrength.fair:
          return '○ Fraca';
        case PasswordStrength.good:
          return '◐ Média';
        case PasswordStrength.strong:
          return '✓ Forte';
      }
    }

    final strengthColor = getStrengthColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          // Barra de força
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: password.isEmpty ? 0 : (strength.index / PasswordStrength.values.length),
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          // Label de força
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                getStrengthLabel(),
                style: TextStyle(
                  color: strengthColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (isStrong)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Atende requisitos',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Enum para representar a força de uma senha
enum PasswordStrength {
  empty,
  weak,
  fair,
  good,
  strong,
}
