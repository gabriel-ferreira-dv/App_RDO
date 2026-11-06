import 'package:flutter/material.dart';

import '../../../../core/widgets/info_chip.dart';
import '../../domain/entities/registro.dart';

// Um registro anterior na lista de importar: onde, quando, a atividade e o
// serviço. O toque escolhe o registro.
class CartaoDeRegistroAnterior extends StatelessWidget {
  final Registro registro;
  final String titulo;
  final String data;
  final VoidCallback aoEscolher;

  const CartaoDeRegistroAnterior({
    super.key,
    required this.registro,
    required this.titulo,
    required this.data,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = registro;
    final descricao = r.descricao.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: aoEscolher,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    data,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(r.atividade, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Sem via em trecho de pista simples: o chip vazio some.
                  if (r.via.trim().isNotEmpty)
                    InfoChip(icone: Icons.swap_horiz, texto: r.via),
                  if (r.estacaInicial.isNotEmpty)
                    InfoChip(
                      icone: Icons.straighten,
                      texto: 'Estaca ${r.estacaInicial} – ${r.estacaFinal}',
                    ),
                  InfoChip(
                      icone: Icons.handyman_outlined, texto: r.servicoNotavel),
                  if (r.servicoNotavelDetalhe.isNotEmpty)
                    InfoChip(
                      icone: Icons.checklist_rtl,
                      texto: r.servicoNotavelDetalhe,
                    ),
                ],
              ),
              if (descricao.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
