import 'package:flutter/material.dart';

// Linha de atalho do Início ("RDO de hoje · Gerar").
class AtalhoDoInicio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final String acao;
  final VoidCallback onTap;

  const AtalhoDoInicio({
    super.key,
    required this.icone,
    required this.titulo,
    this.subtitulo,
    required this.acao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(icone, color: cs.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (subtitulo != null)
                      Text(subtitulo!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(acao,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: cs.onSurface)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
