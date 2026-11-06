import '../../../../core/obra/dia_de_trabalho.dart';
import '../entities/encarregado_da_equipe.dart';
import '../entities/resumo_do_encarregado.dart';
import '../repositories/registros_da_equipe_repository.dart';

// O dia de trabalho de cada encarregado da equipe: registros, paradas, clima
// e efetivo, buscados ao mesmo tempo. Para quem é do turno da noite, a
// madrugada conta no dia anterior.
class CarregarDiaDaEquipe {
  final RegistrosDaEquipeRepository _repositorio;
  final bool Function(String matricula) _ehNoturno;

  const CarregarDiaDaEquipe(this._repositorio,
      {required bool Function(String matricula) ehNoturno})
      : _ehNoturno = ehNoturno;

  Future<List<ResumoDoEncarregado>> call(
      List<EncarregadoDaEquipe> equipe, DateTime dia) async {
    if (equipe.isEmpty) return const [];
    final matriculas = [for (final e in equipe) e.matricula];
    final janela = janelaDoDiaDeTrabalho(dia);

    final (registros, paradas, clima, efetivo) = await (
      _repositorio.registrosEntre(matriculas, janela.de, janela.ate),
      _repositorio.paralisacoesEntre(matriculas, janela.de, janela.ate),
      _repositorio.climaDoDia(matriculas, dia),
      _repositorio.efetivoDoDia(dia),
    ).wait;

    final registrosPorMatricula = porMatriculaNoDia(registros,
        dia: dia,
        matricula: (r) => r.usuarioMatricula,
        quando: (r) => r.criadoEm,
        ehNoturno: _ehNoturno);
    final paradasPorMatricula = porMatriculaNoDia(paradas,
        dia: dia,
        matricula: (p) => p.usuarioMatricula,
        quando: (p) => p.inicio,
        ehNoturno: _ehNoturno);

    return [
      for (final e in equipe)
        ResumoDoEncarregado(
          encarregado: e,
          registros: registrosPorMatricula[e.matricula] ?? const [],
          efetivo: efetivo[e.matricula] ?? const [],
          paralisacoes: paradasPorMatricula[e.matricula] ?? const [],
          clima: clima[e.matricula],
        ),
    ];
  }
}
