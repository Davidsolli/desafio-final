import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../shared/widgets/index.dart';

class RegisterScreen extends StatefulWidget {
  final String? invitationCode;

  const RegisterScreen({
    super.key,
    this.invitationCode,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _prefillLoaded = false;
  late String? _invitationCode;

  // Step 1
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _invitationCode = widget.invitationCode;
    if (_invitationCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefill());
    }
  }

  Future<void> _loadPrefill() async {
    final prefill = await context
        .read<InvitationProvider>()
        .fetchPrefill(_invitationCode!);

    if (!mounted || prefill == null || !prefill.found) return;

    setState(() {
      _prefillLoaded = true;
      if (prefill.name != null) _nameController.text = prefill.name!;
      if (prefill.email != null) _emailController.text = prefill.email!;
    });
  }

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

        final weight = double.tryParse(_weightController.text);
        final height = double.tryParse(_heightController.text);
        final userAge = int.tryParse(_ageController.text);

        final authProvider = context.read<AuthProvider>();
        await authProvider.register(
          name: name,
          email: email,
          password: password,
          role: 'client',
          weightKg: weight,
          heightCm: height,
          age: userAge,
          goalType: _selectedGoal,
          invitationCode: _invitationCode,
        );

        // Faz login automático após registro
        await authProvider.login(
          email: email,
          password: password,
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
      context.go(AppRoutes.login);
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
      backgroundColor: context.colors.background,
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
            child: Icon(Icons.chevron_left, color: context.colors.textSecondary, size: 28),
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
                      color: active ? AppColors.primary : context.colors.surfaceLighter,
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
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('Dados Pessoais',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text('Vamos começar com o básico',
            style: TextStyle(color: AppColors.primary, fontSize: 14)),
        if (_prefillLoaded) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Text('✅', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dados preenchidos do seu pré-cadastro via WhatsApp',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        OmniTextField(
          controller: _nameController,
          labelText: 'Nome completo',
          hintText: 'Seu nome',
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        OmniTextField(
          controller: _emailController,
          labelText: 'Email',
          hintText: 'seu@email.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
        ),
        const SizedBox(height: 12),
        OmniTextField(
          controller: _passwordController,
          labelText: 'Senha',
          hintText: '••••••••',
          obscureText: true,
          prefixIcon: Icons.lock_outlined,
        ),
        const SizedBox(height: 8),
        Text(
          'Mín. 8 caracteres: maiúscula, minúscula, número e caractere especial',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('Dados Corporais',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text('Para cálculos personalizados',
            style: TextStyle(color: AppColors.primary, fontSize: 14)),
        const SizedBox(height: 16),
        OmniTextField(
          controller: _weightController,
          labelText: 'Peso (kg)',
          hintText: '78',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.fitness_center_outlined,
        ),
        const SizedBox(height: 12),
        OmniTextField(
          controller: _heightController,
          labelText: 'Altura (cm)',
          hintText: '175',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.straighten_outlined,
        ),
        const SizedBox(height: 12),
        OmniTextField(
          controller: _ageController,
          labelText: 'Idade',
          hintText: '27',
          keyboardType: TextInputType.number,
          prefixIcon: Icons.cake_outlined,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('Seu Objetivo',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text('Escolha seu foco principal',
            style: TextStyle(color: AppColors.primary, fontSize: 14)),
        const SizedBox(height: 8),
        ...(_goals.map((g) => _buildGoalOption(g)).toList()),
        const SizedBox(height: 8),
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
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : context.colors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
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
                        color: selected ? AppColors.primary : context.colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text(goal['subtitle']!,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
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
      child: OmniButton(
        text: isLast ? 'Criar Conta' : 'Próximo',
        onPressed: (canProceed && !_isLoading) ? _next : null,
        isLoading: _isLoading,
        width: double.infinity,
        height: 52,
      ),
    );
  }

}
