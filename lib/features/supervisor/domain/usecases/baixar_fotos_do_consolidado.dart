import '../entities/foto_consolidada.dart';
import '../entities/resumo_do_encarregado.dart';
import '../regras/fotos_do_consolidado.dart';
import '../repositories/registros_da_equipe_repository.dart';

// Fotos do relatório da equipe, uma lista por encarregado (na ordem de
// [resumos]). Baixa [simultaneas] de cada vez e avisa o progresso; a que
// falha fica de fora.
class BaixarFotosDoConsolidado {
  final RegistrosDaEquipeRepository _repositorio;

  const BaixarFotosDoConsolidado(this._repositorio);

  Future<List<List<FotoConsolidada>>> call(
    List<ResumoDoEncarregado> resumos, {
    void Function(int baixadas, int total)? aoProgredir,
    int simultaneas = 6,
  }) async {
    // Um encarregado por consulta: todos juntos passavam do limite de linhas
    // do servidor e cortavam fotos do dia.
    final caminhos = await Future.wait([
      for (final r in resumos)
        (
          _repositorio.caminhosDasFotos(r.registros),
          _repositorio.caminhosDasFotosDeParalisacao(r.paralisacoes),
        ).wait,
    ]);
    final pendentes = fotosDoConsolidado(
      resumos,
      caminhosDosRegistros: {for (final c in caminhos) ...c.$1},
      caminhosDasParadas: {for (final c in caminhos) ...c.$2},
    );
    aoProgredir?.call(0, pendentes.length);

    final fotos = [for (final _ in resumos) <FotoConsolidada>[]];
    for (var inicio = 0; inicio < pendentes.length; inicio += simultaneas) {
      final lote = pendentes.skip(inicio).take(simultaneas).toList();
      final baixadas =
          await Future.wait([for (final p in lote) _repositorio.baixarFoto(p.caminho)]);
      for (var i = 0; i < lote.length; i++) {
        final bytes = baixadas[i];
        if (bytes == null) continue;
        fotos[lote[i].encarregado]
            .add(FotoConsolidada(bytes: bytes, legenda: lote[i].legenda));
      }
      aoProgredir?.call(inicio + lote.length, pendentes.length);
    }
    return fotos;
  }
}
