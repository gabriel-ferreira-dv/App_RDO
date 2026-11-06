import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';
import '../viewmodels/formulario_de_registro.dart';

// Progresso do registro (Local → Serviço → Fotos), embaixo do título na barra
// do topo.
class ProgressoDasEtapas extends StatelessWidget
    implements PreferredSizeWidget {
  final EtapaDoRegistro etapa;

  const ProgressoDasEtapas({super.key, required this.etapa});

  static const _nomes = ['Local', 'Serviço', 'Fotos'];

  @override
  Size get preferredSize => const Size.fromHeight(34);

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    final numero = etapa.index + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= _nomes.length; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    margin: EdgeInsets.only(left: i == 1 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: i <= numero
                          ? cores.destaque
                          : cores.noCabecalhoSuave.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Etapa $numero de ${_nomes.length} · ${_nomes[numero - 1]}',
            style: TextStyle(color: cores.noCabecalhoSuave, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
