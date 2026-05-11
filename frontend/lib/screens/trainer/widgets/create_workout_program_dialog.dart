import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../models/workout_sheet_model.dart';
import '../../../providers/workout_sheet_provider.dart';

/// Dialog para criar um novo programa/divisão de treino.
class CreateWorkoutProgramDialog extends StatefulWidget {
  final String userId;

  const CreateWorkoutProgramDialog({super.key, required this.userId});

  @override
  State<CreateWorkoutProgramDialog> createState() => _CreateWorkoutProgramDialogState();
}

class _CreateWorkoutProgramDialogState extends State<CreateWorkoutProgramDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goalController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final dto = CreateWorkoutProgramDTO(
      userId: widget.userId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text.trim(),
      goal: _goalController.text.isEmpty ? null : _goalController.text.trim(),
    );

    setState(() => _isSubmitting = true);
    try {
      await context.read<WorkoutSheetProvider>().createProgram(dto);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar programa: ${e.toString()}'),
            backgroundColor: AppColors.accentError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_shared_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Novo Programa',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabel('Nome do Programa *'),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Ex: Divisão ABCDE - Hipertrofia'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: 12),
              _buildLabel('Objetivo (opcional)'),
              TextFormField(
                controller: _goalController,
                decoration: _inputDecoration('Ex: Hipertrofia muscular, definição'),
              ),
              const SizedBox(height: 12),
              _buildLabel('Descrição (opcional)'),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Foco em braços, progressão de carga...'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancelar', style: TextStyle(color: context.colors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Criar',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: context.colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.colors.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
