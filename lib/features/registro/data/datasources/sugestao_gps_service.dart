import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localizacao_service.dart';
import '../../../../core/utils/utm.dart';
import '../../domain/entities/sugestao_gps.dart';
import '../../domain/regras/vias_estaqueamento.dart';
import '../../domain/repositories/localizacao_na_obra.dart';
import 'csv_dados_datasource.dart';
import 'estaqueamento_service.dart';

// Lê as coordenadas das estacas (estacas_coords.csv) e acha a estaca do
// projeto mais perto do GPS.

double? parseCoordenada(dynamic valor) {
  if (valor is num) return valor.toDouble();
  var s = valor.toString().trim();
  final temPonto = s.contains('.');
  final temVirgula = s.contains(',');
  if (temPonto && temVirgula) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (temVirgula) {
    s = s.replaceAll(',', '.');
  } else if ('.'.allMatches(s).length > 1) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

double corrigirEscalaUtm(double valor, double maximoExclusivo) {
  var v = valor;
  while (v >= maximoExclusivo) {
    v /= 10;
  }
  return v;
}

class SugestaoGpsService implements LocalizacaoNaObra {
  SugestaoGpsService._interno();
  static final SugestaoGpsService instancia = SugestaoGpsService._interno();

  static const double distanciaMaximaMetros = 500;

  List<EstacaCoordenada>? _cacheCoordenadas;

  void limparCache() {
    _cacheCoordenadas = null;
    EstaqueamentoService.instancia.limparCache();
  }

  Future<List<EstacaCoordenada>> carregarCoordenadas() async {
    if (_cacheCoordenadas != null) return _cacheCoordenadas!;
    final linhas = await lerDadosCsv(caminhoCSVestacasCoords);
    final estacas = <EstacaCoordenada>[];
    for (final linha in linhas) {
      if (linha.length < 4) continue;
      final e = parseCoordenada(linha[2]);
      final n = parseCoordenada(linha[3]);
      if (e == null || n == null) continue;
      estacas.add(EstacaCoordenada(
        trecho: linha[0].toString().trim(),
        estaca: linha[1].toString().trim(),
        e: corrigirEscalaUtm(e, 1000000),
        n: corrigirEscalaUtm(n, 10000000),
      ));
    }
    _cacheCoordenadas = estacas;
    return estacas;
  }

  // Mesma posição filtrada do mapa e do carimbo.
  Future<PosicaoGps?> _obterPosicao() => LocalizacaoService.instancia
      .posicaoConfiavel(espera: const Duration(seconds: 10));

  @override
  Future<ResultadoSugestaoGps> sugerir() async {
    final estacas = await carregarCoordenadas();
    if (estacas.isEmpty) {
      return ResultadoSugestaoGps.falha(
        'Sem coordenadas de estacas cadastradas (assets/estacas_coords.csv)',
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return ResultadoSugestaoGps.falha(
          'Ative a localização (GPS) do aparelho');
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      return ResultadoSugestaoGps.falha('Permissão de localização negada');
    }

    final posicao = await _obterPosicao();
    if (posicao == null) {
      return ResultadoSugestaoGps.falha(
          'Não foi possível obter sua localização');
    }

    return sugerirParaPosicao(LatLng(posicao.latitude, posicao.longitude));
    // return sugerirParaPosicao(LatLng(-19.989739, -40.413614));
  }

  Future<ResultadoSugestaoGps> sugerirParaPosicao(LatLng posicao) async {
    final estacas = await carregarCoordenadas();
    if (estacas.isEmpty) {
      return ResultadoSugestaoGps.falha(
        'Sem coordenadas de estacas cadastradas (assets/estacas_coords.csv)',
      );
    }

    final utm = latLngParaUtm(posicao);
    final candidatas = estacasPorDistancia(utm.x, utm.y, estacas);
    if (candidatas.first.distanciaMetros > distanciaMaximaMetros) {
      return ResultadoSugestaoGps.falha(
        'Você está a ${formatarDistanciaMetros(candidatas.first.distanciaMetros)} '
        'da estaca mais próxima do projeto',
      );
    }

    // No C1 a via sai da série da estaca.
    final pistaDupla = <String>{
      for (final e in estacas)
        if (estacaDaSerieSul(int.tryParse(numeroDaEstaca(e.estaca)) ?? 0))
          e.trecho,
    };

    // A mais próxima pode não estar no KMxEst: tenta as seguintes no raio.
    final tabela = await EstaqueamentoService.instancia.porNumero();
    for (final candidata in candidatas) {
      if (candidata.distanciaMetros > distanciaMaximaMetros) break;
      final numero = numeroDaEstaca(candidata.estaca.estaca);
      final chave = '${candidata.estaca.trecho}|$numero';
      final info = tabela[chave];
      if (info == null) continue;
      return ResultadoSugestaoGps.ok(SugestaoGps(
        trecho: candidata.estaca.trecho,
        km: info.km,
        estaca: info.rotulo,
        distanciaMetros: candidata.distanciaMetros,
        via: info.via ??
            viaDaEstaca(
              int.tryParse(numero) ?? 0,
              pistaDupla: pistaDupla.contains(candidata.estaca.trecho),
            ),
      ));
    }

    return ResultadoSugestaoGps.falha(
      'Nenhuma estaca próxima encontrada na tabela KM x Estaca',
    );
  }
}
