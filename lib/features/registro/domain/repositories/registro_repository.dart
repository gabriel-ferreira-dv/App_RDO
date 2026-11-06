import '../entities/foto_com_contexto.dart';
import '../entities/registro.dart';

// Os registros (serviço feito) e as fotos de cada um, no banco do celular. O
// envio ao servidor é da sincronização.
abstract interface class RegistroRepository {
  // Grava o registro e devolve o id, para as fotos da câmera apontarem nele.
  Future<int> criarRegistro({
    required int usuarioId,
    required String trecho,
    required String km,
    String kmFinal = '',
    required String via,
    required String atividade,
    required String estacaInicial,
    required String estacaFinal,
    required String servicoNotavel,
    required String servicoNotavelDetalhe,
    double? quantidade,
    String unidade = '',
    String emNomeDeMatricula = '',
    String emNomeDeNome = '',
    required String descricao,
  });

  // [caminhoArquivo] é a foto carimbada; [caminhoOriginal] e
  // [caminhoMinimapa], o que é preciso para refazer o carimbo.
  Future<void> adicionarFoto({
    required int registroId,
    required String caminhoArquivo,
    double? latitude,
    double? longitude,
    String caminhoOriginal = '',
    String caminhoMinimapa = '',
    DateTime? criadoEm,
  });

  // Do mais novo para o mais antigo.
  Future<List<Registro>> listarRegistros(int usuarioId);

  // Cada foto já com os dados do registro dela. [desde] (UTC, ISO 8601)
  // limita aos registros criados a partir dele.
  Future<List<FotoComContexto>> listarFotosComContexto(int usuarioId,
      {String? desde});
}
