import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../registro/domain/entities/foto_com_contexto.dart';
import '../../../registro/domain/entities/grupo_atividade.dart';
import '../../domain/repositories/historico_repository.dart';

// Liga o Histórico aos serviços do Registro (banco do celular e carimbo das
// fotos), recebidos como funções: dá para trocar por falsos nos testes.
class HistoricoRepositoryImpl implements HistoricoRepository {
  final Future<List<FotoComContexto>> Function(int usuarioId) _fotosDoUsuario;
  final Future<CamposDoRegistro?> Function(int registroId) _camposDe;
  final Future<void> Function(int registroId, CamposDoRegistro campos) _editar;

  const HistoricoRepositoryImpl({
    required Future<List<FotoComContexto>> Function(int usuarioId)
        fotosDoUsuario,
    required Future<CamposDoRegistro?> Function(int registroId) camposDe,
    required Future<void> Function(int registroId, CamposDoRegistro campos)
        editar,
  })  : _fotosDoUsuario = fotosDoUsuario,
        _camposDe = camposDe,
        _editar = editar;

  @override
  Future<List<GrupoAtividade>> gruposDoUsuario(int usuarioId) async =>
      agruparPorAtividade(await _fotosDoUsuario(usuarioId));

  @override
  Future<CamposDoRegistro?> camposDoRegistro(int registroId) =>
      _camposDe(registroId);

  @override
  Future<void> corrigir(int registroId, CamposDoRegistro campos) =>
      _editar(registroId, campos);
}
