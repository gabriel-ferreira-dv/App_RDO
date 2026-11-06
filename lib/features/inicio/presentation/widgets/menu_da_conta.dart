import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';
import '../../../auth/models/usuario.dart';

// Iniciais do usuário na barra do topo; o toque mostra nome, e-mail e "Sair".
class MenuDaConta extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback aoSair;

  const MenuDaConta({super.key, required this.usuario, required this.aoSair});

  // "Gabriel Souza" → "GS"; um nome só → a primeira letra.
  static String iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cores = CoresDaObra.de(context);
    final nome = usuario.nome.trim();

    return PopupMenuButton<String>(
      tooltip: 'Conta',
      onSelected: (opcao) {
        if (opcao == 'sair') aoSair();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nome.isEmpty ? 'Usuário' : nome,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(usuario.email, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'sair',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 10),
              Text('Sair'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 14),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: cores.destaque,
          child: Text(
            iniciais(nome),
            style: TextStyle(
              color: cores.naDestaque,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
