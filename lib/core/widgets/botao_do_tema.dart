import 'package:flutter/material.dart';

import '../theme/modo_do_tema.dart';

// Lua no modo claro (passa para o escuro) e sol no escuro (passa para o
// claro). Fica na barra do topo, ao lado das iniciais do usuário.
class BotaoDoTema extends StatelessWidget {
  const BotaoDoTema({super.key});

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: escuro ? 'Modo claro' : 'Modo escuro',
      icon: Icon(escuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () =>
          ModoDoTema.instancia.alternar(Theme.of(context).brightness),
    );
  }
}
