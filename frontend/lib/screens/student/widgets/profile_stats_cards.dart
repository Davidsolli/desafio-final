import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../services/user_service.dart';
import '../../../../shared/widgets/index.dart';

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
            child: OmniStatCard(
              icon: Icons.scale,
              value: imc.toStringAsFixed(1),
              label: 'IMC — $imcLabel',
              valueColor: imcColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OmniStatCard(
              icon: Icons.local_fire_department,
              value: tmb.toString(),
              label: 'TMB (kcal/dia)',
            ),
          ),
        ],
      ),
    );
  }
}
