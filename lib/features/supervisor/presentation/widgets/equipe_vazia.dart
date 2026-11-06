import 'package:flutter/material.dart';

// Supervisor que ainda não escolheu a equipe.
class EquipeVazia extends StatelessWidget {
  const EquipeVazia({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.groups_outlined,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text(
            'Sua equipe ainda está vazia. Toque em "Equipe" para escolher os '
            'encarregados que você supervisiona.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
