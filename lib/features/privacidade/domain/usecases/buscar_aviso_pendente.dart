import '../entities/aviso_de_privacidade.dart';
import '../repositories/aviso_de_privacidade_repository.dart';

// Aviso que o usuário ainda precisa confirmar: primeira abertura nesta
// filial ou versão nova. null quando não há o que confirmar (ou não há
// aviso para mostrar).
class BuscarAvisoPendente {
  final AvisoDePrivacidadeRepository _repositorio;

  const BuscarAvisoPendente(this._repositorio);

  Future<AvisoDePrivacidade?> call({
    required String email,
    required String filial,
  }) async {
    final aviso = await _repositorio.buscar(filial);
    if (aviso == null) return null;
    // A ciência é guardada com a filial do aviso (ConfirmarLeituraDoAviso);
    // procurar com a mesma, porque a do perfil pode vir com espaços.
    final ciencia = await _repositorio.ciencia(email, aviso.filial);
    return ciencia != null && ciencia.cobre(aviso.versao) ? null : aviso;
  }
}
