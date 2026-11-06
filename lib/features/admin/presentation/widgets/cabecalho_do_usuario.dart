import 'package:flutter/material.dart';

// Nome do usuário e "matrícula · N registros" acima dos registros dele.
class CabecalhoDoUsuario extends StatelessWidget {
  final String nome;
  final String resumo;

  const CabecalhoDoUsuario(
      {super.key, required this.nome, required this.resumo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nome,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            resumo,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
