import '../../../supervisor/domain/entities/registro_da_equipe.dart';
import '../repositories/admin_repository.dart';

// Registros do dia (null se a busca falhou) e os endereços das fotos.
typedef RegistrosDoDia = ({
  List<RegistroDaEquipe>? registros,
  Map<String, List<String>> fotos,
});

// Os registros de todos no dia, já com as fotos (só busca as fotos quando
// os registros vieram).
class CarregarRegistrosDosUsuarios {
  final AdminRepository _repositorio;

  const CarregarRegistrosDosUsuarios(this._repositorio);

  Future<RegistrosDoDia> call(DateTime dia) async {
    final registros = await _repositorio.registrosDoDia(dia);
    final fotos = registros == null
        ? const <String, List<String>>{}
        : await _repositorio.enderecosDasFotos(registros);
    return (registros: registros, fotos: fotos);
  }
}
