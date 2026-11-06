import '../../domain/entities/estaca_do_projeto.dart';
import '../../domain/regras/vias_estaqueamento.dart';
import '../../domain/repositories/estaqueamento_repository.dart';
import 'csv_dados_datasource.dart';

// Estacas do projeto por trecho/KM/via, do KMxEst.csv. A série sul do C1
// (2xxx) não está nele: é derivada da norte, com o mesmo KM.
class EstaqueamentoService implements EstaqueamentoRepository {
  EstaqueamentoService._interno();
  static final EstaqueamentoService instancia = EstaqueamentoService._interno();

  List<EstacaDoProjeto>? _cache;

  void limparCache() => _cache = null;

  Future<List<EstacaDoProjeto>> todas() async {
    if (_cache != null) return _cache!;

    final linhas = await lerDadosCsv(caminhoCSVkm);
    // Só trecho e estaca do CSV de coordenadas.
    final coordenadas = await lerDadosCsv(caminhoCSVestacasCoords);

    // Pista dupla = trecho com estacas da série sul.
    final pistaDupla = <String>{
      for (final linha in coordenadas)
        if (linha.length > 1 &&
            estacaDaSerieSul(
                int.tryParse(numeroDaEstaca(linha[1].toString())) ?? 0))
          linha[0].toString().trim(),
    };

    final daPlanilha = <EstacaDoProjeto>[];
    final chavesConhecidas = <String>{};
    for (final linha in linhas) {
      // Obra sem KM pode trazer a coluna do KM vazia ou nem trazer.
      if (linha.length < 2) continue;
      final trecho = linha[0].toString().trim();
      final rotulo = linha[1].toString().trim();
      final numero = int.tryParse(numeroDaEstaca(rotulo));
      if (numero == null) continue;
      if (!chavesConhecidas.add('$trecho|$numero')) continue;
      daPlanilha.add(EstacaDoProjeto(
        trecho: trecho,
        numero: numero,
        rotulo: rotulo,
        km: linha.length > 3 ? linha[3].toString().trim() : '',
        via: viaDaEstaca(numero, pistaDupla: pistaDupla.contains(trecho)),
      ));
    }

    final derivadas = <EstacaDoProjeto>[];
    for (final estaca in daPlanilha) {
      if (!pistaDupla.contains(estaca.trecho)) continue;
      if (estacaDaSerieSul(estaca.numero)) continue;
      final numeroSul = gemeaNaSerieSul(estaca.numero);
      if (chavesConhecidas.contains('${estaca.trecho}|$numeroSul')) continue;
      derivadas.add(EstacaDoProjeto(
        trecho: estaca.trecho,
        numero: numeroSul,
        rotulo: '$numeroSul',
        km: estaca.km,
        via: viaSul,
        kmDerivado: true,
      ));
    }

    _cache = [...daPlanilha, ...derivadas];
    return _cache!;
  }

  // Estacas de um KM, filtradas pela via (null = as duas séries).
  Future<List<String>> rotulosDoKm(String trecho, String km,
      {String? via}) async {
    final todas = await this.todas();
    final lista = todas
        .where((e) =>
            e.trecho == trecho &&
            e.km == km &&
            (via == null || e.via == null || e.via == via))
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
    return lista.map((e) => e.rotulo).toList();
  }

  // Estacas do [km] e dos [kmsVizinhos] KMs de cada lado, filtradas pela via,
  // em ordem de estaca.
  @override
  Future<List<EstacaDoProjeto>> doKmEVizinhos(String trecho, String km,
      {String? via}) {
    final n = int.tryParse(km.trim());
    final de = n == null ? km : '${n - kmsVizinhos}';
    final ate = n == null ? km : '${n + kmsVizinhos}';
    return doIntervalo(trecho, de, ate, via: via);
  }

  // Todas as estacas do trecho, filtradas pela via: o local de quem não usa
  // KM.
  @override
  Future<List<EstacaDoProjeto>> doTrecho(String trecho, {String? via}) async {
    final todas = await this.todas();
    return todas
        .where((e) =>
            e.trecho == trecho &&
            (via == null || e.via == null || e.via == via))
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
  }

  // Estacas do KM [kmDe] ao [kmAte], filtradas pela via.
  Future<List<EstacaDoProjeto>> doIntervalo(
      String trecho, String kmDe, String kmAte,
      {String? via}) async {
    final todas = await this.todas();
    return todas
        .where((e) =>
            e.trecho == trecho &&
            (via == null || e.via == null || e.via == via) &&
            kmNoIntervalo(e.km, kmDe, kmAte))
        .toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
  }

  // Índice "trecho|numero" → estaca.
  Future<Map<String, EstacaDoProjeto>> porNumero() async {
    final todas = await this.todas();
    return {for (final e in todas) '${e.trecho}|${e.numero}': e};
  }
}
