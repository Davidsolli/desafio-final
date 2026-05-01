import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../theme/app_colors.dart';
import '../../../../services/user_service.dart';

class ProfileStatsCards extends StatelessWidget {
  final UserResponse user;

  const ProfileStatsCards({super.key, required this.user});

  Color _getIMCColor(double imc) {
    if (imc < 18.5) return Colors.blue;
    if (imc < 25) return Colors.green;
    if (imc < 30) return Colors.orange;
    if (imc < 35) return Colors.red;
    return Colors.red.shade900;
  }

  @override
  Widget build(BuildContext context) {
    final imc = user.imc;
    final imcLabel = user.imcLabel;
    final imcColor = _getIMCColor(imc);
    final tmb = user.tmb;

    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.scale, color: AppColors.primary, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    imc.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: imcColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'IMC — $imcLabel',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_fire_department,
                      color: AppColors.primary, size: 20),
                  const SizedBox(height: 8),
                  Text(
                    tmb.toString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TMB (kcal/dia)',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
