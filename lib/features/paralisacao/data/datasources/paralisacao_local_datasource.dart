import 'package:sqflite/sqflite.dart' show Database;

import '../../../../core/database/db_helper.dart';

// Acesso cru ao banco do celular (sqflite): só SQL, sem regra. As regras e a
// conversão para entidades ficam no repositório.
abstract interface class ParalisacaoLocalDataSource {
  Future<int> inserir(Map<String, Object?> dados);
  Future<void> atualizar(int id, Map<String, Object?> dados);

  // Não excluídas do usuário com início em [de, ate) (ISO em UTC).
  Future<List<Map<String, Object?>>> doUsuarioEntre(
      int usuarioId, String de, String ate);

  Future<void> inserirFoto(Map<String, Object?> dados);
  Future<List<Map<String, Object?>>> fotosDe(int paralisacaoId);

  // Linhas {paralisacao_id, n}.
  Future<List<Map<String, Object?>>> contarFotos(List<int> ids);

  // Trecho e KM do registro mais recente desde [desde] (ISO em UTC).
  Future<Map<String, Object?>?> ultimoRegistroDesde(
      int usuarioId, String desde);
}

class ParalisacaoSqflite implements ParalisacaoLocalDataSource {
  const ParalisacaoSqflite();

  Future<Database> get _db => DbHelper.instancia.database;

  @override
  Future<int> inserir(Map<String, Object?> dados) async =>
      (await _db).insert('paralisacoes', dados);

  @override
  Future<void> atualizar(int id, Map<String, Object?> dados) async =>
      (await _db)
          .update('paralisacoes', dados, where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<Map<String, Object?>>> doUsuarioEntre(
          int usuarioId, String de, String ate) async =>
      (await _db).query(
        'paralisacoes',
        where: 'usuario_id = ? AND excluida = 0 AND inicio >= ? AND inicio < ?',
        whereArgs: [usuarioId, de, ate],
        orderBy: 'inicio',
      );

  @override
  Future<void> inserirFoto(Map<String, Object?> dados) async =>
      (await _db).insert('fotos_paralisacao', dados);

  @override
  Future<List<Map<String, Object?>>> fotosDe(int paralisacaoId) async =>
      (await _db).query('fotos_paralisacao',
          where: 'paralisacao_id = ?',
          whereArgs: [paralisacaoId],
          orderBy: 'id');

  @override
  Future<List<Map<String, Object?>>> contarFotos(List<int> ids) async =>
      (await _db).rawQuery(
        'SELECT paralisacao_id, COUNT(*) AS n FROM fotos_paralisacao '
        'WHERE paralisacao_id IN (${List.filled(ids.length, '?').join(',')}) '
        'GROUP BY paralisacao_id',
        ids,
      );

  @override
  Future<Map<String, Object?>?> ultimoRegistroDesde(
      int usuarioId, String desde) async {
    final linhas = await (await _db).query(
      'registros',
      columns: ['trecho', 'km'],
      where: 'usuario_id = ? AND criado_em >= ?',
      whereArgs: [usuarioId, desde],
      orderBy: 'id DESC',
      limit: 1,
    );
    return linhas.isEmpty ? null : linhas.first;
  }
}
