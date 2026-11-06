import 'package:flutter/material.dart';

// Destaque vermelho de uma paralisação em andamento, com "Retomar serviço".
class CartaoParadoAgora extends StatelessWidget {
  final String titulo;

  // Local e observação; vazio esconde a linha.
  final String detalhe;
  final VoidCallback aoRetomar;
  final VoidCallback aoEditar;

  const CartaoParadoAgora({
    super.key,
    required this.titulo,
    required this.detalhe,
    required this.aoRetomar,
    required this.aoEditar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cores.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: theme.textTheme.titleSmall?.copyWith(
                color: cores.onErrorContainer, fontWeight: FontWeight.bold),
          ),
          if (detalhe.isNotEmpty)
            Text(
              detalhe,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cores.onErrorContainer),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: aoRetomar,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Retomar serviço'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Editar ou fotografar',
                onPressed: aoEditar,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
