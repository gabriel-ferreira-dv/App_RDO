import '../../../../core/extensions/data_hora_extensions.dart';
import '../entities/foto_consolidada.dart';
import '../entities/resumo_do_encarregado.dart';

// Fotos que vão para o relatório da equipe, na ordem do PDF: de cada
// encarregado, as dos registros e depois as das paralisações.
// [caminhosDosRegistros] e [caminhosDasParadas] são por chave
// ("dispositivo|id_local").
List<FotoParaBaixar> fotosDoConsolidado(
  List<ResumoDoEncarregado> resumos, {
  required Map<String, List<String>> caminhosDosRegistros,
  required Map<String, List<String>> caminhosDasParadas,
}) =>
    [
      for (var i = 0; i < resumos.length; i++) ...[
        for (final r in resumos[i].registros)
          for (final caminho in caminhosDosRegistros[r.chave] ?? const <String>[])
            FotoParaBaixar(
              encarregado: i,
              caminho: caminho,
              legenda: r.estacaInicial.isEmpty
                  ? r.servicoNotavel
                  : '${r.servicoNotavel} - estaca ${r.estacaInicial}',
            ),
        for (final p in resumos[i].paralisacoes)
          for (final caminho in caminhosDasParadas[p.chave] ?? const <String>[])
            FotoParaBaixar(
              encarregado: i,
              caminho: caminho,
              legenda: 'Paralisação - ${p.motivo} - ${p.inicio.horaCurta}',
            ),
      ],
    ];
