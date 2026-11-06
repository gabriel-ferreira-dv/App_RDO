import 'package:flutter/material.dart';

// Quadro com um número do dia ("Hoje · 7 registros").
class NumeroDoDia extends StatelessWidget {
  final String rotulo;
  final String valor;
  final String detalhe;

  // Cor do detalhe quando ele é um alerta (serviço parado agora).
  final Color? corDoDetalhe;

  final VoidCallback? onTap;

  const NumeroDoDia({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.detalhe,
    this.corDoDetalhe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suave = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rotulo,
                  style: theme.textTheme.labelMedium?.copyWith(color: suave)),
              const SizedBox(height: 2),
              Text(
                valor,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                detalhe,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: corDoDetalhe ?? suave,
                  fontWeight: corDoDetalhe == null ? null : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
