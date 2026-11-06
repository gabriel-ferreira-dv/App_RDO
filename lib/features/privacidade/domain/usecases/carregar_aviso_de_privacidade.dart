import '../entities/aviso_de_privacidade.dart';
import '../repositories/aviso_de_privacidade_repository.dart';

// Aviso da filial para consulta (Mais → Privacidade, tela de login).
class CarregarAvisoDePrivacidade {
  final AvisoDePrivacidadeRepository _repositorio;

  const CarregarAvisoDePrivacidade(this._repositorio);

  Future<AvisoDePrivacidade?> call(String filial) =>
      _repositorio.buscar(filial);
}
