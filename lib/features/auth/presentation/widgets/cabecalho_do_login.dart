import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';

// Faixa grafite do topo do login, com o logo (branco, o mesmo do carimbo) e o
// nome do app. O formulário sobe um pouco por cima dela.
class CabecalhoDoLogin extends StatelessWidget {
  final String subtitulo;

  const CabecalhoDoLogin({super.key, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = CoresDaObra.de(context);
    return Container(
      width: double.infinity,
      color: cores.cabecalho,
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.paddingOf(context).top + 48, 24, 64),
      child: Column(
        children: [
          Image.asset(
            'assets/logo.png',
            height: 56,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.route, size: 56, color: cores.noCabecalho),
          ),
          const SizedBox(height: 18),
          Text(
            'RDO cbm',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cores.noCabecalho,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cores.noCabecalhoSuave),
          ),
          const SizedBox(height: 14),
          // O amarelo de obra, como assinatura.
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cores.destaque,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
