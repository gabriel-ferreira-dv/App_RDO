// Uma função da equipe com quantas pessoas a exerceram no dia.
class FuncaoEquipe {
  final String funcao;
  final int quantidade;

  const FuncaoEquipe({required this.funcao, required this.quantidade});

  // Linha no formato que o RDO já usa em RelatorioDiarioInfo.equipe.
  String get linha => '$quantidade - $funcao';
}
