import 'package:flutter/material.dart';

// "Parou" e "Voltou", o aviso de que voltou em outro dia e o "Ainda parado".
class HorariosDaParada extends StatelessWidget {
  final String rotuloInicio;
  final String rotuloFim;
  final String? avisoDeOutroDia;
  final bool aindaParado;
  final VoidCallback aoEscolherInicio;
  final VoidCallback aoEscolherFim;
  final ValueChanged<bool> aoMudarAindaParado;

  const HorariosDaParada({
    super.key,
    required this.rotuloInicio,
    required this.rotuloFim,
    required this.avisoDeOutroDia,
    required this.aindaParado,
    required this.aoEscolherInicio,
    required this.aoEscolherFim,
    required this.aoMudarAindaParado,
  });

  @override
  Widget build(BuildContext context) {
    final aviso = avisoDeOutroDia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: aoEscolherInicio,
                icon: const Icon(Icons.pause_circle_outline),
                label: Text(rotuloInicio),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                // Ainda parado: não há hora de volta para escolher.
                onPressed: aindaParado ? null : aoEscolherFim,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(rotuloFim),
              ),
            ),
          ],
        ),
        if (aviso != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(aviso, style: Theme.of(context).textTheme.bodySmall),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ainda parado'),
          subtitle: const Text('Toque em "Retomar serviço" quando voltar'),
          value: aindaParado,
          onChanged: aoMudarAindaParado,
        ),
      ],
    );
  }
}
