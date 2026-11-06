import 'package:flutter/material.dart';

// Título em negrito e uma linha por item, com o texto de quando está vazia.
class SecaoDoCartao extends StatelessWidget {
  final String titulo;
  final List<String> itens;
  final String? vazio;

  const SecaoDoCartao(this.titulo, this.itens, {super.key, this.vazio});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          if (itens.isEmpty && vazio != null)
            Text(vazio!,
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            for (final item in itens)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $item', style: const TextStyle(fontSize: 12)),
              ),
        ],
      ),
    );
  }
}
