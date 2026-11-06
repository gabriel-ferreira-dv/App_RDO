import 'package:flutter/material.dart';

import '../../../supervisor/domain/entities/encarregado_da_equipe.dart';

// Supervisor lançando em nome de um encarregado. O aviso fica porque a foto
// sai com o GPS de quem fotografou.
class SeletorDeAutoria extends StatelessWidget {
  final List<EncarregadoDaEquipe> equipe;
  final EncarregadoDaEquipe? escolhido;
  final ValueChanged<String?> aoEscolher;

  const SeletorDeAutoria({
    super.key,
    required this.equipe,
    required this.escolhido,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final para = escolhido;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: para?.matricula,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Registrar em nome de',
            prefixIcon: Icon(Icons.assignment_ind_outlined),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Meu próprio')),
            for (final e in equipe)
              DropdownMenuItem(value: e.matricula, child: Text(e.nome)),
          ],
          onChanged: aoEscolher,
        ),
        if (para != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'O registro entra no nome de ${para.nome}, marcado como '
              'lançado por você. A foto sai com a sua localização.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
