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

class AdminStudentFormScreen extends StatefulWidget {
  final bool isEditing;
  final String? studentId;
  final String? studentName;
  final String? studentEmail;
  final String? studentPhone;

  const AdminStudentFormScreen({
    Key? key,
    this.isEditing = false,
    this.studentId,
    this.studentName,
    this.studentEmail,
    this.studentPhone,
  }) : super(key: key);

  @override
  State<AdminStudentFormScreen> createState() => _AdminStudentFormScreenState();
}

class _AdminStudentFormScreenState extends State<AdminStudentFormScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      if (widget.studentName != null) {
        _nameController.text = widget.studentName!;
      }
      if (widget.studentEmail != null) {
        _emailController.text = widget.studentEmail!;
      }
      if (widget.studentPhone != null) {
        // Formatar o telefone: 11111111111 -> (11) 11111-1111
        final phone = widget.studentPhone!;
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
    _ageController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveStudent() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome do aluno')),
      );
      return;
    }

    if (!widget.isEditing && _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email é obrigatório para novo aluno')),
      );
      return;
    }

    if (!widget.isEditing && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha é obrigatória para novo aluno')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<AdminProvider>();

      if (widget.isEditing && widget.studentId != null) {
        // Editar aluno
        final phone = _phoneController.text.isEmpty
          ? null
          : _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
        final updateDto = UpdateAdminUserDTO(
          name: _nameController.text,
          phoneWhatsapp: phone,
        );
        await provider.updateStudent(widget.studentId!, updateDto);
      } else {
        // Criar novo aluno (como trainer para simplificar, já que clients precisam de convite)
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
              widget.isEditing
                  ? 'Aluno atualizado com sucesso!'
                  : 'Aluno adicionado com sucesso!',
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
        title: Text(widget.isEditing ? 'Editar Aluno' : 'Adicionar Aluno'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informações do Aluno',
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
                hintText: 'João Cliente',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              enabled: !_isLoading && !widget.isEditing,
              decoration: InputDecoration(
                labelText: widget.isEditing ? 'Email' : 'Email *',
                hintText: 'joao@email.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              enabled: !_isLoading,
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneFormatter()],
              decoration: InputDecoration(
                labelText: 'Telefone/WhatsApp',
                hintText: '(11) 99999-8888',
                prefixIcon: const Icon(Icons.phone_outlined),
                helperText: 'Formato: (XX) XXXXX-XXXX',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ageController,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Idade',
                hintText: '25',
                prefixIcon: const Icon(Icons.cake_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (!widget.isEditing) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha *',
                  hintText: 'Mínimo 8 caracteres com maiúscula, número e caractere especial',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Salvar Alterações',
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
