import 'dart:math';

// Coordenadas das estacas em UTM SIRGAS2000/24S (Trecho;Estaca;E;N). O
// casamento com o KMxEst.csv é pelo número da estaca.
class EstacaCoordenada {
  final String trecho;
  final String estaca;
  final double e;
  final double n;

  EstacaCoordenada({
    required this.trecho,
    required this.estaca,
    required this.e,
    required this.n,
  });
}

// Valores prontos para preencher o formulário da Home.
class SugestaoGps {
  final String trecho;
  final String km;
  final String estaca;
  final double distanciaMetros;

  // Via pela série da estaca (pista dupla); null em pista simples.
  final String? via;

  SugestaoGps({
    required this.trecho,
    required this.km,
    required this.estaca,
    required this.distanciaMetros,
    this.via,
  });
}

// Uma sugestão ou uma mensagem de erro para o usuário.
class ResultadoSugestaoGps {
  final SugestaoGps? sugestao;
  final String? erro;

  ResultadoSugestaoGps.ok(SugestaoGps this.sugestao) : erro = null;
  ResultadoSugestaoGps.falha(String this.erro) : sugestao = null;
}

String formatarDistanciaMetros(double metros) {
  if (metros >= 1000) return '${(metros / 1000).toStringAsFixed(1)} km';
  return '${metros.round()} m';
}

// Estacas ordenadas da mais próxima à mais distante do ponto (e, n) no plano UTM.
List<({EstacaCoordenada estaca, double distanciaMetros})> estacasPorDistancia(
  double e,
  double n,
  List<EstacaCoordenada> estacas,
) {
  final resultado = estacas.map((est) {
    final dx = est.e - e;
    final dy = est.n - n;
    return (estaca: est, distanciaMetros: sqrt(dx * dx + dy * dy));
  }).toList();
  resultado.sort((a, b) => a.distanciaMetros.compareTo(b.distanciaMetros));
  return resultado;
}

({EstacaCoordenada estaca, double distanciaMetros})? estacaMaisProxima(
  double e,
  double n,
  List<EstacaCoordenada> estacas,
) {
  final ordenadas = estacasPorDistancia(e, n, estacas);
  return ordenadas.isEmpty ? null : ordenadas.first;
}
