import 'dart:io';

import 'package:flutter/material.dart';

// Miniaturas das fotos da paralisação; o toque abre a galeria.
class FotosDaParada extends StatelessWidget {
  final List<String> caminhos;
  final VoidCallback aoAbrir;

  const FotosDaParada(
      {super.key, required this.caminhos, required this.aoAbrir});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos (${caminhos.length})',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SizedBox(
          height: 72,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final caminho in caminhos)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: aoAbrir,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(File(caminho),
                          width: 96, height: 72, fit: BoxFit.cover),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
