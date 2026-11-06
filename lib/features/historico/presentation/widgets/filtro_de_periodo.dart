import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';
import '../../domain/entities/item_do_historico.dart';

// Faixa escura logo abaixo da barra do topo, com os períodos do Histórico.
class FiltroDePeriodo extends StatelessWidget {
  final PeriodoDoHistorico escolhido;
  final ValueChanged<PeriodoDoHistorico> aoEscolher;

  const FiltroDePeriodo({
    super.key,
    required this.escolhido,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    return Container(
      width: double.infinity,
      color: cores.cabecalho,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final periodo in PeriodoDoHistorico.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _opcao(cores, periodo, periodo == escolhido),
              ),
          ],
        ),
      ),
    );
  }

  Widget _opcao(
      CoresDaObra cores, PeriodoDoHistorico periodo, bool selecionado) {
    return Material(
      color: selecionado
          ? cores.destaque
          : cores.noCabecalhoSuave.withValues(alpha: 0.18),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => aoEscolher(periodo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            periodo.rotulo,
            style: TextStyle(
              color: selecionado ? cores.naDestaque : cores.noCabecalho,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
