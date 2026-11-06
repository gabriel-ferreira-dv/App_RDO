import 'package:flutter/material.dart';

// Etiqueta arredondada com ícone, para estados ("Enviado", "Aguardando
// sinal") e filtros. As cores vêm de CoresDaObra.
class Etiqueta extends StatelessWidget {
  final String texto;
  final IconData? icone;
  final Color cor;
  final Color fundo;

  const Etiqueta({
    super.key,
    required this.texto,
    this.icone,
    required this.cor,
    required this.fundo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 13, color: cor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
