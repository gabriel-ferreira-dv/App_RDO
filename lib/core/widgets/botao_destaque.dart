import 'package:flutter/material.dart';

import '../theme/cores_app.dart';

// Botão amarelo da ação principal da tela (uma por tela: "Tirar fotos",
// "Novo registro"). Ocupa a largura toda e é alto, para acertar de luva.
class BotaoDestaque extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final VoidCallback? onPressed;

  const BotaoDestaque({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icone),
      label: Text(rotulo),
      style: FilledButton.styleFrom(
        backgroundColor: cores.destaque,
        foregroundColor: cores.naDestaque,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
