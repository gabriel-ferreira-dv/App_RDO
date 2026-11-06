import '../entities/foto_da_paralisacao.dart';
import '../entities/paralisacao.dart';

// O que a funcionalidade precisa dos dados, sem dizer onde ficam (hoje, o
// banco do celular; o envio ao servidor é da sincronização). Toda mudança
// marca a paralisação como pendente de envio.
abstract interface class ParalisacaoRepository {
  // Grava (nova ou editada) e devolve o id.
  Future<int> salvar(Paralisacao paralisacao);

  // Fecha a paralisação em [quando] (retomou o serviço).
  Future<void> encerrar(int id, DateTime quando);

  // Só marca: o servidor precisa saber que ela saiu.
  Future<void> excluir(int id);

  // Paralisações do dia de trabalho [dia], na ordem do dia.
  Future<List<Paralisacao>> listarDoDia(int usuarioId, DateTime dia,
      {required bool noturno});

  Future<void> adicionarFoto({
    required int paralisacaoId,
    required String caminhoArquivo,
    double? latitude,
    double? longitude,
    required DateTime quando,
  });

  Future<List<FotoDaParalisacao>> fotosDe(int paralisacaoId);

  // Quantas fotos tem cada paralisação de [ids].
  Future<Map<int, int>> contarFotos(List<int> ids);

  // Trecho e KM do último registro feito desde [desde] (sugestão para a
  // paralisação nova).
  Future<LocalDaParada?> ultimoLocalDesde(int usuarioId, DateTime desde);
}
