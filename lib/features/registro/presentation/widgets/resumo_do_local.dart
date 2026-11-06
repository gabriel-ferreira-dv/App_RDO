import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';

// Bloco escuro no topo da etapa Serviço: onde o registro está sendo feito,
// com o atalho para voltar e mudar.
class ResumoDoLocal extends StatelessWidget {
  final String local;
  final String? via;

  // Encarregado em nome de quem o supervisor está registrando.
  final String? emNomeDe;

  final VoidCallback onAlterar;

  const ResumoDoLocal({
    super.key,
    required this.local,
    this.via,
    this.emNomeDe,
    required this.onAlterar,
  });

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    final detalhes = [
      if (via != null && via!.isNotEmpty) via!,
      if (emNomeDe != null) 'em nome de $emNomeDe',
    ].join(' · ');

    return Material(
      color: cores.cabecalho,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onAlterar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Icon(Icons.place_outlined, color: cores.destaque, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      local,
                      style: TextStyle(
                        color: cores.noCabecalho,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detalhes.isNotEmpty)
                      Text(
                        detalhes,
                        style: TextStyle(
                            color: cores.noCabecalhoSuave, fontSize: 12),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onAlterar,
                style: TextButton.styleFrom(foregroundColor: cores.destaque),
                child: const Text('Alterar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
