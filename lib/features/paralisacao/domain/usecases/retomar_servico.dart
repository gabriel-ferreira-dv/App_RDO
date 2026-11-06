import '../entities/paralisacao.dart';
import '../repositories/paralisacao_repository.dart';

// "Retomar serviço": fecha a paralisação agora e devolve quanto tempo ficou
// parado.
class RetomarServico {
  final ParalisacaoRepository _repositorio;
  final DateTime Function() _agora;

  const RetomarServico(this._repositorio,
      {DateTime Function() agora = DateTime.now})
      : _agora = agora;

  Future<Duration> call(Paralisacao paralisacao) async {
    final quando = _agora();
    await _repositorio.encerrar(paralisacao.id!, quando);
    return quando.difference(paralisacao.inicio);
  }
}
