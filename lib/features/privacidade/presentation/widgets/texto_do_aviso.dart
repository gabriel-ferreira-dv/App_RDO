import 'package:flutter/material.dart';

import '../../domain/entities/linha_do_aviso.dart';

// O texto do aviso: versão e data no topo, títulos em negrito.
class TextoDoAviso extends StatelessWidget {
  final String versaoEData;
  final List<LinhaDoAviso> linhas;

  const TextoDoAviso({
    super.key,
    required this.versaoEData,
    required this.linhas,
  });

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    // Dá para selecionar e copiar o texto.
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(versaoEData, style: texto.bodySmall),
          const SizedBox(height: 8),
          for (final linha in linhas) _Linha(linha, texto),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final LinhaDoAviso linha;
  final TextTheme texto;

  const _Linha(this.linha, this.texto);

  @override
  Widget build(BuildContext context) {
    if (linha.vazia) return const SizedBox(height: 8);
    if (linha.ehTitulo) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          linha.texto,
          style: texto.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(linha.texto, style: texto.bodyMedium),
    );
  }
}
