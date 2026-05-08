import 'package:flutter/material.dart';
import 'omni_button.dart';

class OmniErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String retryLabel;

  const OmniErrorState({
    Key? key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Tentar novamente',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OmniButton(
                text: retryLabel,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
