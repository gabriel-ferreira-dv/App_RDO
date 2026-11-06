import '../../../../core/obra/dia_de_trabalho.dart';
import '../../../registro/domain/repositories/registro_repository.dart';
import '../entities/registro_da_equipe.dart';

// O que o encarregado registrou no dia de trabalho, lido do aparelho (vale
// sem internet), do mais antigo ao mais novo, no formato do mapa de avanço.
// O que ele lançou em nome de outro não é dele.
class RegistrosDoAparelhoNoDia {
  final RegistroRepository _registros;
  final int usuarioId;
  final String nome;
  final String matricula;
  final bool Function() _noturno;

  const RegistrosDoAparelhoNoDia(
    this._registros, {
    required this.usuarioId,
    required this.nome,
    required this.matricula,
    required bool Function() noturno,
  }) : _noturno = noturno;

  Future<List<RegistroDaEquipe>> call(DateTime dia) async {
    final noturno = _noturno();
    return [
      for (final r in await _registros.listarRegistros(usuarioId))
        if (!r.lancadoPorTerceiro)
          if (DateTime.tryParse(r.criadoEm)?.toLocal() case final quando?
              when ehDoDiaDeTrabalho(quando, dia, noturno: noturno))
            RegistroDaEquipe(
              dispositivoId: '',
              idLocal: r.id ?? 0,
              usuarioNome: nome,
              usuarioMatricula: matricula,
              trecho: r.trecho,
              km: r.km,
              kmFinal: r.kmFinal,
              via: r.via,
              atividade: r.atividade,
              estacaInicial: r.estacaInicial,
              estacaFinal: r.estacaFinal,
              servicoNotavel: r.servicoNotavel,
              servicoNotavelDetalhe: r.servicoNotavelDetalhe,
              quantidade: r.quantidade,
              unidade: r.unidade,
              descricao: r.descricao,
              criadoEm: quando,
            ),
    ]..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
  }
}
