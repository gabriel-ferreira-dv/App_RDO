import '../entities/resumo_das_paralisacoes.dart';
import '../repositories/paralisacao_repository.dart';

// As paralisações do dia de trabalho, já com a contagem de fotos.
class CarregarParalisacoesDoDia {
  final ParalisacaoRepository _repositorio;

  const CarregarParalisacoesDoDia(this._repositorio);

  Future<ResumoDasParalisacoes> call(int usuarioId, DateTime dia,
      {required bool noturno}) async {
    final lista =
        await _repositorio.listarDoDia(usuarioId, dia, noturno: noturno);
    final fotos =
        await _repositorio.contarFotos([for (final p in lista) p.id!]);
    return ResumoDasParalisacoes(lista, fotos);
  }
}
