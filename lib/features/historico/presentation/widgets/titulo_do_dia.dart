import 'package:flutter/material.dart';

// "Hoje", "Ontem", "sex., 10/07" entre os registros de dias diferentes.
class TituloDoDia extends StatelessWidget {
  final String texto;

  const TituloDoDia(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        texto,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
