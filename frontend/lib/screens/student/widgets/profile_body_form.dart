import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../../services/user_service.dart';
import '../../../../providers/user_provider.dart';

class ProfileBodyForm extends StatefulWidget {
  final UserResponse user;

  const ProfileBodyForm({super.key, required this.user});

  @override
  State<ProfileBodyForm> createState() => _ProfileBodyFormState();
}

class _ProfileBodyFormState extends State<ProfileBodyForm> {
  late TextEditingController nameController;
  late TextEditingController weightController;
  late TextEditingController heightController;
  late TextEditingController ageController;
  late String selectedGender;
  String selectedActivityLevel = '1.55';

  @override
  void initState() {
    super.initState();
    _initControllers(widget.user);
  }

  void _initControllers(UserResponse user) {
    nameController = TextEditingController(text: user.name);
    weightController = TextEditingController(text: (user.weight ?? 0.0).toStringAsFixed(1));
    heightController = TextEditingController(text: (user.height ?? 0.0).toStringAsFixed(0));
    ageController = TextEditingController(text: (user.age ?? 0).toString());
    selectedGender = user.gender ?? 'male';
  }

  @override
  void didUpdateWidget(ProfileBodyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _initControllers(widget.user);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    weightController.dispose();
    heightController.dispose();
    ageController.dispose();
    super.dispose();
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }

  InputDecoration _buildInputDeco() {
    return InputDecoration(
      filled: true,
      fillColor: context.colors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final tdee = widget.user.tdee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Dados Corporais',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('Nome'),
          TextField(
            controller: nameController,
            decoration: _buildInputDeco(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Peso (kg)'),
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDeco(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Altura (cm)'),
                    TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDeco(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Idade'),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDeco(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Sexo'),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      onChanged: (v) =>
                          setState(() => selectedGender = v ?? 'male'),
                      items: const [
                        DropdownMenuItem(
                          value: 'male',
                          child: Text('Masculino'),
                        ),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Feminino'),
                        ),
                      ],
                      decoration: _buildInputDeco(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('Nível de Atividade (para TDEE)'),
          DropdownButtonFormField<String>(
            value: selectedActivityLevel,
            onChanged: (v) =>
                setState(() => selectedActivityLevel = v ?? '1.55'),
            items: const [
              DropdownMenuItem(
                value: '1.2',
                child: Text('Sedentário'),
              ),
              DropdownMenuItem(
                value: '1.375',
                child: Text('Levemente ativo'),
              ),
              DropdownMenuItem(
                value: '1.55',
                child: Text('Moderadamente ativo'),
              ),
              DropdownMenuItem(
                value: '1.725',
                child: Text('Muito ativo'),
              ),
              DropdownMenuItem(
                value: '1.9',
                child: Text('Extremamente ativo'),
              ),
            ],
            decoration: _buildInputDeco(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Gasto Calórico Diário (TDEE)',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: context.colors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$tdee kcal',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                try {
                  await userProvider.updateUser(
                    name: nameController.text.trim(),
                    weight: double.tryParse(weightController.text) ??
                        widget.user.weight,
                    height: double.tryParse(heightController.text) ??
                        widget.user.height,
                    age: int.tryParse(ageController.text) ?? widget.user.age,
                    gender: selectedGender,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alterações salvas!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao salvar: $e')),
                    );
                  }
                }
              },
              child: Text(
                'Salvar Alterações',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
