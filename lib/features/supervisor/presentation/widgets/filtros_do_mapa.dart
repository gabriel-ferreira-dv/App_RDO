import 'package:flutter/material.dart';

import '../../../../core/widgets/seletor_de_dia.dart';
import '../viewmodels/mapa_avanco_view_model.dart';

// Topo do mapa de avanço: o dia (encarregado) ou o período (equipe), o
// serviço e, no da equipe, o encarregado.
class FiltrosDoMapa extends StatelessWidget {
  final bool doEncarregado;
  final bool carregando;

  final DateTime dia;
  final DateTime hoje;
  final ValueChanged<DateTime> aoMudarDia;

  final PeriodoDoMapa periodo;
  final ValueChanged<PeriodoDoMapa> aoEscolherPeriodo;

  final List<String> servicos;
  final String? servico;
  final ValueChanged<String?> aoEscolherServico;

  final List<({String matricula, String nome})> encarregados;
  final String? encarregado;
  final ValueChanged<String?> aoEscolherEncarregado;

  const FiltrosDoMapa({
    super.key,
    required this.doEncarregado,
    required this.carregando,
    required this.dia,
    required this.hoje,
    required this.aoMudarDia,
    required this.periodo,
    required this.aoEscolherPeriodo,
    required this.servicos,
    required this.servico,
    required this.aoEscolherServico,
    required this.encarregados,
    required this.encarregado,
    required this.aoEscolherEncarregado,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          children: [
            if (doEncarregado)
              SeletorDeDia(
                dia: dia,
                hoje: hoje,
                habilitado: !carregando,
                aoMudar: aoMudarDia,
              )
            else
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<PeriodoDoMapa>(
                  segments: [
                    for (final p in PeriodoDoMapa.values)
                      ButtonSegment(
                        value: p,
                        label: Text(p.rotulo, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  selected: {periodo},
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  onSelectionChanged: (s) => aoEscolherPeriodo(s.first),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('servico_${servico}_${servicos.length}'),
                    initialValue: servico,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Serviço', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      for (final s in servicos)
                        DropdownMenuItem(
                          value: s,
                          child: Text(s, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: aoEscolherServico,
                  ),
                ),
                if (!doEncarregado) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('enc_${encarregado}_${encarregados.length}'),
                      initialValue: encarregado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Encarregado', isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        for (final e in encarregados)
                          DropdownMenuItem(
                            value: e.matricula,
                            child: Text(e.nome, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: aoEscolherEncarregado,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
