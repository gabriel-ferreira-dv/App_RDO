import '../entities/aviso_de_privacidade.dart';
import '../entities/ciencia_do_aviso.dart';
import '../repositories/aviso_de_privacidade_repository.dart';

// "Li e entendi": guarda que o usuário leu esta versão do aviso da filial.
class ConfirmarLeituraDoAviso {
  final AvisoDePrivacidadeRepository _repositorio;
  final DateTime Function() _agora;

  const ConfirmarLeituraDoAviso(this._repositorio,
      {DateTime Function() agora = DateTime.now})
      : _agora = agora;

  Future<void> call(String email, AvisoDePrivacidade aviso) =>
      _repositorio.guardarCiencia(
          email, aviso.filial, CienciaDoAviso(aviso.versao, _agora()));
}
