import 'package:flutter/material.dart';

import '../extensions/data_hora_extensions.dart';

// Dia anterior, o dia (abre o calendário) e o dia seguinte (até [hoje]).
class SeletorDeDia extends StatelessWidget {
  final DateTime dia;
  final ValueChanged<DateTime> aoMudar;

  // Último dia que dá para escolher; sem ele, o dia de hoje do calendário.
  // No turno da noite, a madrugada ainda é "hoje" do dia anterior.
  final DateTime? hoje;

  // false desliga os três botões (ex.: enquanto carrega).
  final bool habilitado;

  const SeletorDeDia({
    super.key,
    required this.dia,
    required this.aoMudar,
    this.hoje,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    final ultimo = (hoje ?? DateTime.now()).soDia;
    final ehHoje = dia.soDia == ultimo;
    final data = dia.dataCurta;

    return Row(
      children: [
        IconButton(
          tooltip: 'Dia anterior',
          onPressed: habilitado
              ? () => aoMudar(DateTime(dia.year, dia.month, dia.day - 1))
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton.icon(
            onPressed: habilitado
                ? () async {
                    final escolhido = await showDatePicker(
                      context: context,
                      initialDate: dia,
                      firstDate: DateTime(2020),
                      lastDate: ultimo,
                    );
                    if (escolhido != null) aoMudar(escolhido.soDia);
                  }
                : null,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(ehHoje ? 'Hoje, $data' : data),
          ),
        ),
        IconButton(
          tooltip: 'Dia seguinte',
          onPressed: !habilitado || ehHoje
              ? null
              : () => aoMudar(DateTime(dia.year, dia.month, dia.day + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
