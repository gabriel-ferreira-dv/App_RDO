import 'package:flutter/material.dart';

// Trecho e KM (opcionais) da paralisação.
class LocalDaParada extends StatelessWidget {
  final List<String> trechos;
  final String? trecho;
  final List<String> kms;
  final String? km;
  final ValueChanged<String?> aoEscolherTrecho;
  final ValueChanged<String?> aoEscolherKm;

  const LocalDaParada({
    super.key,
    required this.trechos,
    required this.trecho,
    required this.kms,
    required this.km,
    required this.aoEscolherTrecho,
    required this.aoEscolherKm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Onde (opcional)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // Recria quando a sugestão do último registro chega.
          key: ValueKey('trecho_${trecho}_${trechos.length}'),
          initialValue: trecho,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Trecho', isDense: true),
          items: _opcoes(trechos),
          onChanged: aoEscolherTrecho,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          // Recria ao trocar o trecho, para o KM antigo sair.
          key: ValueKey('km_${trecho}_${kms.length}'),
          initialValue: km,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'KM', isDense: true),
          items: _opcoes(kms),
          onChanged: trecho == null ? null : aoEscolherKm,
        ),
      ],
    );
  }

  static List<DropdownMenuItem<String>> _opcoes(List<String> valores) => [
        const DropdownMenuItem(value: null, child: Text('Não informar')),
        for (final v in valores) DropdownMenuItem(value: v, child: Text(v)),
      ];
}
