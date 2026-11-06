import 'package:flutter/material.dart';

// Uma paralisação encerrada na lista, com o número de fotos.
class LinhaDaParalisacao extends StatelessWidget {
  final String descricao;
  final int fotos;
  final VoidCallback aoTocar;

  const LinhaDaParalisacao({
    super.key,
    required this.descricao,
    required this.fotos,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history_toggle_off),
      title: Text(descricao),
      trailing: fotos > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_camera_outlined, size: 16),
                Text(' $fotos'),
              ],
            )
          : null,
      onTap: aoTocar,
    );
  }
}
