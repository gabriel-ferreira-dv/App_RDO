import 'package:flutter/material.dart';

// Atividades como botões grandes de tocar (são poucas: Terraplanagem,
// Drenagem, Pavimentação...), no lugar de uma lista para pesquisar.
class EscolhaDeAtividade extends StatelessWidget {
  final List<String> atividades;
  final String? escolhida;
  final ValueChanged<String> aoEscolher;

  const EscolhaDeAtividade({
    super.key,
    required this.atividades,
    required this.escolhida,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (atividades.isEmpty) {
      return Text(
        'Carregando as atividades do trecho…',
        style: TextStyle(color: cs.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final atividade in atividades)
          _chip(cs, atividade, selecionada: atividade == escolhida),
      ],
    );
  }

  Widget _chip(ColorScheme cs, String atividade, {required bool selecionada}) {
    final corDoTexto = selecionada ? cs.onPrimary : cs.onSurface;
    return ChoiceChip(
      selected: selecionada,
      onSelected: (_) => aoEscolher(atividade),
      showCheckmark: false,
      avatar: Icon(_icone(atividade), size: 18, color: corDoTexto),
      label: Text(atividade),
      labelStyle: TextStyle(color: corDoTexto, fontWeight: FontWeight.w600),
      selectedColor: cs.primary,
      backgroundColor: cs.surfaceContainerLowest,
      side: BorderSide(color: selecionada ? cs.primary : cs.outlineVariant),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }

  // Ícone pelo começo do nome (os nomes vêm do CSV da obra).
  static IconData _icone(String atividade) {
    final nome = atividade.toLowerCase();
    if (nome.startsWith('terra')) return Icons.terrain_outlined;
    if (nome.startsWith('dren')) return Icons.water_drop_outlined;
    if (nome.startsWith('pav')) return Icons.add_road;
    if (nome.startsWith('civil')) return Icons.foundation;
    if (nome.startsWith('sinal')) return Icons.traffic_outlined;
    return Icons.construction;
  }
}
