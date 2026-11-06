import '../entities/paralisacao.dart';
import '../repositories/paralisacao_repository.dart';

// Resultado de salvar: o id gravado, ou o motivo de não ter gravado.
sealed class ResultadoAoSalvar {
  const ResultadoAoSalvar();
}

class Salvou extends ResultadoAoSalvar {
  final int id;
  const Salvou(this.id);
}

class NaoSalvou extends ResultadoAoSalvar {
  final String problema;
  const NaoSalvou(this.problema);
}

// Confere as regras (motivo, término depois do início) e grava.
class SalvarParalisacao {
  final ParalisacaoRepository _repositorio;

  const SalvarParalisacao(this._repositorio);

  Future<ResultadoAoSalvar> call({
    int? id,
    required int usuarioId,
    required String? motivo,
    required DateTime inicio,
    DateTime? fim,
    String observacao = '',
    String trecho = '',
    String km = '',
    required String criadoEm,
  }) async {
    final problema =
        problemaDaParalisacao(motivo: motivo, inicio: inicio, fim: fim);
    if (problema != null) return NaoSalvou(problema);
    final gravado = await _repositorio.salvar(Paralisacao(
      id: id,
      usuarioId: usuarioId,
      motivo: motivo!,
      observacao: observacao.trim(),
      trecho: trecho,
      km: km,
      inicio: inicio.toUtc(),
      fim: fim?.toUtc(),
      criadoEm: criadoEm,
    ));
    return Salvou(gravado);
  }
}
