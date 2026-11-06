import 'dart:typed_data';

import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../relatorio/domain/entities/funcao_equipe.dart';
import '../entities/clima_da_equipe.dart';
import '../entities/paralisacao_da_equipe.dart';
import '../entities/registro_da_equipe.dart';

// O que a equipe produziu, lido do servidor. As buscas do dia voltam vazias
// quando falham (a tela mostra o que der).
abstract interface class RegistrosDaEquipeRepository {
  // Registros das [matriculas] com criado_em em [de, ate), do mais antigo ao
  // mais novo.
  Future<List<RegistroDaEquipe>> registrosEntre(
      List<String> matriculas, DateTime de, DateTime ate);

  // Paralisações (não excluídas) com início em [de, ate), em ordem.
  Future<List<ParalisacaoDaEquipe>> paralisacoesEntre(
      List<String> matriculas, DateTime de, DateTime ate);

  // Clima que cada matrícula informou no RDO do [dia].
  Future<Map<String, ClimaDaEquipe>> climaDoDia(
      List<String> matriculas, DateTime dia);

  // Efetivo do SIMOVA de cada encarregado no [dia] (matrícula → funções).
  Future<Map<String, List<FuncaoEquipe>>> efetivoDoDia(DateTime dia);

  // Registros desde [desde] (null = tudo), em ordem; null se a busca falhar.
  Future<List<RegistroDaEquipe>?> registrosDoPeriodo(List<String> matriculas,
      {DateTime? desde});

  // Corrige no servidor. null = corrigiu; senão, a mensagem do erro.
  Future<String?> corrigir(RegistroDaEquipe registro, CamposDoRegistro campos);

  // Caminhos das fotos no Storage, por chave ("dispositivo|id_local").
  Future<Map<String, List<String>>> caminhosDasFotos(
      List<RegistroDaEquipe> registros);
  Future<Map<String, List<String>>> caminhosDasFotosDeParalisacao(
      List<ParalisacaoDaEquipe> paralisacoes);

  // Bytes da foto; null se falhar (o relatório sai sem ela).
  Future<Uint8List?> baixarFoto(String caminho);
}
