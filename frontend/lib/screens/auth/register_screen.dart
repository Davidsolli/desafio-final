import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Step 2
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();

  // Step 3
  String? _selectedGoal;

  final _goals = const [
    {'id': 'gain_mass', 'emoji': '💪', 'title': 'Ganhar Massa', 'subtitle': 'Hipertrofia e força'},
    {'id': 'lose_weight', 'emoji': '🔥', 'title': 'Emagrecer', 'subtitle': 'Perda de gordura'},
    {'id': 'maintain', 'emoji': '⚖️', 'title': 'Manter Peso', 'subtitle': 'Composição corporal'},
    {'id': 'endurance', 'emoji': '🏃', 'title': 'Resistência', 'subtitle': 'Condicionamento físico'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _next() async {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        _showError('Nome, email e senha são obrigatórios');
        return;
      }

      try {
        setState(() => _isLoading = true);

        final authProvider = context.read<AuthProvider>();
        await authProvider.register(
          name: name,
          email: email,
          password: password,
          role: 'client',
          phoneWhatsapp: null,
        );

        if (mounted) {
          context.go(AppRoutes.home);
        }
      } catch (e) {
        if (mounted) {
          _showError(e.toString());
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
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
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _currentStep == 0
                    ? _buildStep1()
                    : _currentStep == 1
                        ? _buildStep2()
                        : _buildStep3(),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _back,
            child: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: List.generate(3, (i) {
                final active = i <= _currentStep;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.surfaceLighter,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_currentStep + 1}/3',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Dados Pessoais',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Vamos começar com o básico',
            style: TextStyle(color: AppColors.primary, fontSize: 14)),
        const SizedBox(height: 28),
        _label('Nome completo'),
        _input(_nameController, 'Seu nome'),
        const SizedBox(height: 16),
        _label('Email'),
        _input(_emailController, 'seu@email.com', keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _label('Senha'),
        _inputPassword(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Dados Corporais',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Para cálculos personalizados',
            style: TextStyle(color: AppColors.primary, fontSize: 14)),
        const SizedBox(height: 28),
        _label('Peso (kg)'),
        _input(_weightController, '78', keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _label('Altura (cm)'),
        _input(_heightController, '175', keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _label('Idade'),
        _input(_ageController, '27', keyboardType: TextInputType.number),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Seu Objetivo',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Escolha seu foco principal',
            style: TextStyle(color: AppColors.primary, fontSize: 14)),
        const SizedBox(height: 24),
        ...(_goals.map((g) => _buildGoalOption(g)).toList()),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildGoalOption(Map<String, String> goal) {
    final selected = _selectedGoal == goal['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = goal['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(goal['emoji']!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal['title']!,
                    style: TextStyle(
                        color: selected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text(goal['subtitle']!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    final isLast = _currentStep == 2;
    final canProceed = isLast ? _selectedGoal != null : true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: (canProceed && !_isLoading) ? _next : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isLast ? 'Criar Conta' : 'Próximo',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    if (!isLast) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      );

  Widget _input(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  Widget _inputPassword() => TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textMuted,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      );
}
