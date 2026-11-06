import '../../../../core/obra/dia_de_trabalho.dart';
import '../repositories/paralisacao_repository.dart';

// Há paralisação aberta no dia de trabalho atual? (O ponto vermelho do
// "Mais".)
class EstaParadoAgora {
  final ParalisacaoRepository _repositorio;
  final DateTime Function() _agora;

  const EstaParadoAgora(this._repositorio,
      {DateTime Function() agora = DateTime.now})
      : _agora = agora;

  Future<bool> call(int usuarioId, {required bool noturno}) async {
    final hoje = diaDoTurno(_agora(), noturno: noturno);
    final lista =
        await _repositorio.listarDoDia(usuarioId, hoje, noturno: noturno);
    return lista.any((p) => p.emAndamento);
  }
}
