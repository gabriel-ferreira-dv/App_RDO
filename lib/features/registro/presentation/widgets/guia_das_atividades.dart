import 'package:flutter/material.dart';

import '../../domain/regras/atividades_descricoes.dart';

// Guia das atividades, aberto pelo "O que é cada uma?" da etapa Serviço.
Future<void> mostrarGuiaDasAtividades(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, rolagem) => ListView(
          controller: rolagem,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('Guia das atividades', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'O que cada atividade abrange, para escolher a certa.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final entrada in descricoesAtividades.entries) ...[
              Text(entrada.key,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(entrada.value, style: theme.textTheme.bodyMedium),
              const Divider(height: 24),
            ],
          ],
        ),
      );
    },
  );
}
