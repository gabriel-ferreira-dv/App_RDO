import 'package:flutter/material.dart';

import '../../domain/regras/medicao.dart';

// Estaca de destino, a distância até ela, e "Trocar"/"Encerrar".
class PainelDeDestino extends StatelessWidget {
  final String titulo;

  // "Você está a 120 m daqui"; null sem GPS.
  final String? distancia;
  final VoidCallback aoTrocar;
  final VoidCallback aoEncerrar;

  const PainelDeDestino({
    super.key,
    required this.titulo,
    required this.distancia,
    required this.aoTrocar,
    required this.aoEncerrar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: Colors.lightBlueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (distancia != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 32),
                child: Text(distancia!),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: aoTrocar,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Trocar'),
                ),
                TextButton.icon(
                  onPressed: aoEncerrar,
                  icon: const Icon(Icons.close),
                  label: const Text('Encerrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Distância e área do que foi marcado, com "Desfazer" e "Limpar".
class PainelDeMedicao extends StatelessWidget {
  final Medicao medicao;
  final VoidCallback aoDesfazer;
  final VoidCallback aoLimpar;

  const PainelDeMedicao({
    super.key,
    required this.medicao,
    required this.aoDesfazer,
    required this.aoLimpar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(medicao.textoDistancia,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (medicao.temArea) Text(medicao.textoArea),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: medicao.vazia ? null : aoDesfazer,
                  icon: const Icon(Icons.undo),
                  label: const Text('Desfazer'),
                ),
                TextButton.icon(
                  onPressed: medicao.vazia ? null : aoLimpar,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Limpar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Botões no canto do mapa: ir para estaca, voltar ao GPS e medir.
class BotoesDoMapa extends StatelessWidget {
  final bool medindo;
  final bool comDestino;
  final bool seguindoUsuario;
  final VoidCallback aoNavegar;
  final VoidCallback aoVoltarParaMim;
  final VoidCallback aoAlternarMedicao;

  const BotoesDoMapa({
    super.key,
    required this.medindo,
    required this.comDestino,
    required this.seguindoUsuario,
    required this.aoNavegar,
    required this.aoVoltarParaMim,
    required this.aoAlternarMedicao,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!medindo) ...[
          FloatingActionButton.small(
            heroTag: 'btnNavegar',
            tooltip: 'Ir para uma estaca',
            backgroundColor: comDestino ? Colors.lightBlueAccent : null,
            onPressed: aoNavegar,
            child: const Icon(Icons.signpost_outlined),
          ),
          const SizedBox(height: 10),
          // Volta ao GPS; destacado enquanto o mapa segue a pessoa.
          FloatingActionButton.small(
            heroTag: 'btnMinhaLocalizacao',
            tooltip: seguindoUsuario
                ? 'Seguindo sua localização'
                : 'Voltar para minha localização',
            backgroundColor: seguindoUsuario ? Colors.amber : null,
            onPressed: aoVoltarParaMim,
            child: Icon(
                seguindoUsuario ? Icons.my_location : Icons.location_searching),
          ),
          const SizedBox(height: 10),
        ],
        FloatingActionButton(
          heroTag: 'btnMedicao',
          tooltip: medindo ? 'Encerrar medição' : 'Medir no mapa',
          backgroundColor: medindo ? Colors.amber : null,
          onPressed: aoAlternarMedicao,
          child: Icon(medindo ? Icons.close : Icons.straighten),
        ),
      ],
    );
  }
}
