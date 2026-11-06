import 'package:flutter/material.dart';

// Lista sem nada para mostrar: ícone, título e, se houver, um detalhe.
class AvisoDaLista extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String detalhe;

  const AvisoDaLista({
    super.key,
    required this.icone,
    required this.titulo,
    this.detalhe = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icone, size: 52, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(titulo, style: theme.textTheme.titleSmall),
          if (detalhe.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detalhe,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
