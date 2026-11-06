import '../../../../core/database/db_helper.dart';
import '../../domain/entities/foto_com_contexto.dart';
import '../../domain/entities/registro.dart';
import '../../domain/repositories/registro_repository.dart';

// Grava e lista os registros (operações) e as fotos de cada um no banco do
// celular (sqflite).
class RegistroRepositoryImpl implements RegistroRepository {
  const RegistroRepositoryImpl();

  // Cria o registro com os campos selecionados na Home e retorna o id gerado,
  // usado depois para vincular as fotos tiradas na câmera.
  @override
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
  }) async {
    final db = await DbHelper.instancia.database;
    return db.insert('registros', {
      'usuario_id': usuarioId,
      'trecho': trecho,
      'km': km,
      'km_final': kmFinal,
      'via': via,
      'atividade': atividade,
      'estaca_inicial': estacaInicial,
      'estaca_final': estacaFinal,
      'servico_notavel': servicoNotavel,
      'servico_notavel_detalhe': servicoNotavelDetalhe,
      'quantidade': quantidade,
      'unidade': unidade,
      'em_nome_de_matricula': emNomeDeMatricula,
      'em_nome_de_nome': emNomeDeNome,
      'descricao': descricao,
      'criado_em': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // [caminhoArquivo] é a foto carimbada; [caminhoOriginal] e [caminhoMinimapa],
  // o que é preciso para refazer o carimbo.
  @override
  Future<void> adicionarFoto({
    required int registroId,
    required String caminhoArquivo,
    double? latitude,
    double? longitude,
    String caminhoOriginal = '',
    String caminhoMinimapa = '',
    DateTime? criadoEm,
  }) async {
    final db = await DbHelper.instancia.database;
    await db.insert('fotos', {
      'registro_id': registroId,
      'caminho_arquivo': caminhoArquivo,
      'latitude': latitude,
      'longitude': longitude,
      'criado_em': (criadoEm ?? DateTime.now()).toUtc().toIso8601String(),
      'caminho_original': caminhoOriginal,
      'caminho_minimapa': caminhoMinimapa,
    });
  }

  @override
  Future<List<Registro>> listarRegistros(int usuarioId) async {
    final db = await DbHelper.instancia.database;
    final resultado = await db.query(
      'registros',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy: 'id DESC',
    );
    return resultado.map(Registro.fromMap).toList();
  }

  // Todas as fotos do usuário já com os dados do registro-pai embutidos
  // (trecho/km/via/atividade/estacas/serviço/descrição), usada tanto pelo
  // Histórico (agrupamento por atividade) quanto pelo relatório em PDF.
  // [desde] (UTC, ISO 8601) limita aos registros criados a partir dele.
  @override
  Future<List<FotoComContexto>> listarFotosComContexto(int usuarioId,
      {String? desde}) async {
    final db = await DbHelper.instancia.database;
    final resultado = await db.rawQuery('''
      SELECT
        f.id AS foto_id,
        f.caminho_arquivo AS caminho_arquivo,
        f.latitude AS latitude,
        f.longitude AS longitude,
        f.criado_em AS foto_criado_em,
        f.sincronizado AS foto_sincronizada,
        f.carimbo_pendente AS carimbo_pendente,
        r.id AS registro_id,
        r.sincronizado AS registro_sincronizado,
        r.edicao_pendente AS edicao_pendente,
        r.editado_em AS editado_em,
        r.trecho AS trecho,
        r.km AS km,
        r.km_final AS km_final,
        r.via AS via,
        r.atividade AS atividade,
        r.estaca_inicial AS estaca_inicial,
        r.estaca_final AS estaca_final,
        r.servico_notavel AS servico_notavel,
        r.servico_notavel_detalhe AS servico_notavel_detalhe,
        r.quantidade AS quantidade,
        r.unidade AS unidade,
        r.em_nome_de_nome AS em_nome_de_nome,
        r.registrado_por_nome AS registrado_por_nome,
        r.descricao AS descricao,
        r.criado_em AS registro_criado_em
      FROM fotos f
      INNER JOIN registros r ON r.id = f.registro_id
      WHERE r.usuario_id = ? ${desde == null ? '' : 'AND r.criado_em >= ?'}
      ORDER BY r.id DESC, f.id DESC
    ''', [usuarioId, if (desde != null) desde]);
    return resultado.map(FotoComContexto.fromMap).toList();
  }
}
