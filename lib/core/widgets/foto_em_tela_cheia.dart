import 'package:flutter/material.dart';

// Abre a foto de [endereco] (da internet) em tela cheia, com zoom.
Future<void> mostrarFotoEmTelaCheia(BuildContext context, String endereco) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(child: InteractiveViewer(child: Image.network(endereco))),
          SafeArea(
            child: IconButton(
              color: Colors.white,
              icon: const Icon(Icons.close),
              tooltip: 'Fechar',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
