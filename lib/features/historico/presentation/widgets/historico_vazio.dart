import 'package:flutter/material.dart';

// Período sem registros; [aoVerTodos] nulo esconde o "Ver todos". Rola, para
// o puxar-para-atualizar funcionar mesmo vazio.
class HistoricoVazio extends StatelessWidget {
  final String mensagem;
  final String detalhe;
  final VoidCallback? aoVerTodos;

  const HistoricoVazio({
    super.key,
    required this.mensagem,
    this.detalhe = 'Os registros que você fizer aparecem aqui',
    this.aoVerTodos,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, limites) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: limites.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_outlined,
                    size: 56, color: theme.colorScheme.outline),
                const SizedBox(height: 12),
                Text(mensagem, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  detalhe,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (aoVerTodos != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: aoVerTodos,
                    child: const Text('Ver todos'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
