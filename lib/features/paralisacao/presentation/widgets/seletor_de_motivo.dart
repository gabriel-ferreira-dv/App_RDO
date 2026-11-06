import 'package:flutter/material.dart';

// Chips com os motivos da paralisação.
class SeletorDeMotivo extends StatelessWidget {
  final List<String> motivos;
  final String? escolhido;
  final ValueChanged<String> aoEscolher;

  const SeletorDeMotivo({
    super.key,
    required this.motivos,
    required this.escolhido,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Motivo', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final motivo in motivos)
              ChoiceChip(
                label: Text(motivo),
                selected: escolhido == motivo,
                onSelected: (_) => aoEscolher(motivo),
              ),
          ],
        ),
      ],
    );
  }
}
