import '../../../paralisacao/domain/entities/paralisacao.dart' show tempoParado;
import '../../../relatorio/domain/entities/funcao_equipe.dart';
import 'clima_da_equipe.dart';
import 'encarregado_da_equipe.dart';
import 'paralisacao_da_equipe.dart';
import 'registro_da_equipe.dart';

// O dia de um encarregado: registros do app, efetivo apontado, paradas e clima.
class ResumoDoEncarregado {
  final EncarregadoDaEquipe encarregado;
  final List<RegistroDaEquipe> registros;
  final List<FuncaoEquipe> efetivo;
  final List<ParalisacaoDaEquipe> paralisacoes;
  final ClimaDaEquipe? clima;

  const ResumoDoEncarregado({
    required this.encarregado,
    required this.registros,
    required this.efetivo,
    this.paralisacoes = const [],
    this.clima,
  });

  int get totalPessoas => efetivo.fold(0, (soma, f) => soma + f.quantidade);

  // Tempo parado nas paralisações encerradas.
  Duration get totalParado =>
      tempoParado([for (final p in paralisacoes) (inicio: p.inicio, fim: p.fim)]);

  bool get aindaParado => paralisacoes.any((p) => p.fim == null);
}
