import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../registro/domain/entities/grupo_atividade.dart';

// Os registros do usuário guardados no celular, e a correção deles.
abstract interface class HistoricoRepository {
  // Todos os registros do usuário, agrupados por atividade.
  Future<List<GrupoAtividade>> gruposDoUsuario(int usuarioId);

  // O que dá para corrigir no registro; null se ele não existe mais.
  Future<CamposDoRegistro?> camposDoRegistro(int registroId);

  // Grava a correção no celular e refaz o carimbo das fotos. O envio ao
  // servidor fica pendente para a sincronização.
  Future<void> corrigir(int registroId, CamposDoRegistro campos);
}
