import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../supervisor/domain/entities/registro_da_equipe.dart';

// O admin do painel (tabela admins_painel) usando o app: vê os registros de
// todos os usuários e corrige qualquer um. Quem é admin e o que ele enxerga
// quem decide é o servidor (ver supabase_consultas/admin_corrige_registros.sql).
abstract interface class AdminRepository {
  // Pergunta ao servidor; sem internet, vale a última resposta.
  Future<bool> souAdmin();

  // Registros de todos no dia de trabalho [dia] (o turno da noite vai até o
  // meio-dia seguinte). null se a busca falhar.
  Future<List<RegistroDaEquipe>?> registrosDoDia(DateTime dia);

  // Endereços temporários das fotos de cada registro (o bucket é privado),
  // pela chave do registro. Vazio se falhar.
  Future<Map<String, List<String>>> enderecosDasFotos(
      List<RegistroDaEquipe> registros);

  // Grava a correção no servidor (precisa de internet). null = deu certo;
  // senão, a mensagem do problema. A correção chega no celular do dono, que
  // refaz o carimbo das fotos na próxima sincronização.
  Future<String?> corrigir(RegistroDaEquipe registro, CamposDoRegistro campos);
}
