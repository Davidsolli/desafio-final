import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin_models.dart';

class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    if (text.length > 11) {
      return oldValue;
    }

    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 0) {
        formatted += '(';
      } else if (i == 2) {
        formatted += ') ';
      } else if (i == 7) {
        formatted += '-';
      }
      formatted += text[i];
    }

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AdminPTFormScreen extends StatefulWidget {
  final bool isEditing;
  final String? trainerId;
  final String? trainerName;
  final String? trainerEmail;
  final String? trainerPhone;
  final String? trainerRole;

  const AdminPTFormScreen({
    Key? key,
    this.isEditing = false,
    this.trainerId,
    this.trainerName,
    this.trainerEmail,
    this.trainerPhone,
    this.trainerRole,
  }) : super(key: key);

  @override
  State<AdminPTFormScreen> createState() => _AdminPTFormScreenState();
}

class _AdminPTFormScreenState extends State<AdminPTFormScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;

  Set<String> _selectedSpecialties = {'personal_trainer'};

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      if (widget.trainerName != null) {
        _nameController.text = widget.trainerName!;
      }
      if (widget.trainerEmail != null) {
        _emailController.text = widget.trainerEmail!;
      }
      if (widget.trainerPhone != null) {
        final phone = widget.trainerPhone!;
        if (phone.isNotEmpty) {
          String formatted = '';
          for (int i = 0; i < phone.length; i++) {
            if (i == 0) {
              formatted += '(';
            } else if (i == 2) {
              formatted += ') ';
            } else if (i == 7) {
              formatted += '-';
            }
            formatted += phone[i];
          }
          _phoneController.text = formatted;
        }
      }
      if (widget.trainerRole != null) {
        _selectedSpecialties = widget.trainerRole!
            .split(',')
            .map((r) => r.trim())
            .where((r) => r == 'personal_trainer' || r == 'nutritionist')
            .toSet();
        if (_selectedSpecialties.isEmpty) {
          _selectedSpecialties = {'personal_trainer'};
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  bool _validatePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length == 11;
  }

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[@!#$%^&*]'))) return false;
    return true;
  }

  Future<void> _saveProfessional() async {
    setState(() {
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
    });

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome')),
      );
      return;
    }

    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos uma especialidade')),
      );
      return;
    }

    if (!widget.isEditing) {
      if (_emailController.text.isEmpty) {
        setState(() => _emailError = 'Email é obrigatório');
        return;
      }

      if (!_validateEmail(_emailController.text)) {
        setState(() => _emailError = 'Email inválido');
        return;
      }

      if (_passwordController.text.isEmpty) {
        setState(() => _passwordError = 'Senha é obrigatória');
        return;
      }

      if (!_validatePassword(_passwordController.text)) {
        setState(() => _passwordError =
            'Mín 8 chars: maiúscula, minúscula, número, caractere especial (@!#\$%^&*)');
        return;
      }
    }

    if (_phoneController.text.isNotEmpty && !_validatePhone(_phoneController.text)) {
      setState(() => _phoneError = 'Telefone deve ter 11 dígitos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<AdminProvider>();

      if (widget.isEditing && widget.trainerId != null) {
        final phone = _phoneController.text.isEmpty
          ? null
          : _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
        final sorted = _selectedSpecialties.toList()..sort();
        final updateDto = UpdateAdminUserDTO(
          name: _nameController.text,
          phoneWhatsapp: phone,
          role: sorted.join(','),
        );
        await provider.updateTrainer(widget.trainerId!, updateDto);
      } else {
        final phone = _phoneController.text.isEmpty
          ? null
          : _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
        final createDto = CreateTrainerDTO(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          phoneWhatsapp: phone,
          specialties: _selectedSpecialties.toList(),
        );
        await provider.createTrainer(createDto);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing ? 'Profissional atualizado!' : 'Profissional criado!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Profissional' : 'Adicionar Profissional'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informações do Profissional',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Nome completo *',
                hintText: 'João Silva',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Especialidades *',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Personal Trainer'),
                    secondary: const Icon(Icons.fitness_center),
                    value: _selectedSpecialties.contains('personal_trainer'),
                    onChanged: _isLoading
                        ? null
                        : (v) => setState(() {
                              if (v!) {
                                _selectedSpecialties.add('personal_trainer');
                              } else {
                                _selectedSpecialties.remove('personal_trainer');
                              }
                            }),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    title: const Text('Nutricionista'),
                    secondary: const Icon(Icons.restaurant_menu),
                    value: _selectedSpecialties.contains('nutritionist'),
                    onChanged: _isLoading
                        ? null
                        : (v) => setState(() {
                              if (v!) {
                                _selectedSpecialties.add('nutritionist');
                              } else {
                                _selectedSpecialties.remove('nutritionist');
                              }
                            }),
                  ),
                ],
              ),
            ),
            if (_selectedSpecialties.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  'Selecione ao menos uma especialidade',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              enabled: !_isLoading && !widget.isEditing,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: widget.isEditing ? 'Email (não pode alterar)' : 'Email *',
                hintText: 'joao@fitloop.com',
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _emailError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              enabled: !_isLoading,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneFormatter()],
              decoration: InputDecoration(
                labelText: 'Telefone/WhatsApp',
                hintText: '(11) 99999-9999',
                prefixIcon: const Icon(Icons.phone_outlined),
                errorText: _phoneError,
                helperText: 'Formato: (XX) XXXXX-XXXX',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (!widget.isEditing) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Senha *',
                  hintText: 'Digite uma senha forte',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                  ),
                  errorText: _passwordError,
                  errorMaxLines: 3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.border),
                ),
                child: Text(
                  'Requisitos: Mínimo 8 caracteres, pelo menos uma letra maiúscula, uma letra minúscula, um número e um caractere especial (@!#\$%^&*)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfessional,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.isEditing ? 'Atualizar' : 'Criar Profissional',
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
    );
  }
}
