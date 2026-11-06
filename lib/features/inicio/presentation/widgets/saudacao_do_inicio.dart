import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';

// Título da barra do topo no Início: a filial em cima, pequena, e o "Bom
// dia, Gabriel" embaixo.
class SaudacaoDoInicio extends StatelessWidget {
  final String filial;
  final String saudacao;
  final String primeiroNome;

  const SaudacaoDoInicio({
    super.key,
    required this.filial,
    required this.saudacao,
    required this.primeiroNome,
  });

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Filial $filial',
          style: TextStyle(color: cores.noCabecalhoSuave, fontSize: 12),
        ),
        Text(
          primeiroNome.isEmpty ? saudacao : '$saudacao, $primeiroNome',
          style: TextStyle(
            color: cores.noCabecalho,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
