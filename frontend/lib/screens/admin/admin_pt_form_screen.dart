import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
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

  const AdminPTFormScreen({
    Key? key,
    this.isEditing = false,
    this.trainerId,
    this.trainerName,
    this.trainerEmail,
    this.trainerPhone,
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
        // Formatar o telefone: 11111111111 -> (11) 11111-1111
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

  Future<void> _saveTrainer() async {
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

    // Validações apenas para criação (não para edição)
    if (!widget.isEditing) {
      // Na criação, email e senha são obrigatórios
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
        final updateDto = UpdateAdminUserDTO(
          name: _nameController.text,
          phoneWhatsapp: phone,
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
        );
        await provider.createTrainer(createDto);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing ? 'Trainer atualizado!' : 'Trainer criado!',
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Trainer' : 'Adicionar Trainer'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informações do Trainer',
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Requisitos: Mínimo 8 caracteres, pelo menos uma letra maiúscula, uma letra minúscula, um número e um caractere especial (@!#\$%^&*)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTrainer,
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
                        widget.isEditing ? 'Atualizar' : 'Criar Trainer',
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
