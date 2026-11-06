import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../../../../core/utils/utm.dart';

// Medição no mapa: comprimento do caminho marcado e área do polígono, no
// plano UTM da obra.
class Medicao {
  final List<LatLng> pontos;

  const Medicao(this.pontos);

  bool get vazia => pontos.isEmpty;
  bool get temLinha => pontos.length >= 2;
  bool get temArea => pontos.length >= 3;

  double get distanciaMetros => distanciaEmMetros(pontos);
  double get areaM2 => areaEmM2(pontos);

  String get textoDistancia =>
      vazia ? 'Toque no mapa para marcar pontos' : 'Distância: '
          '${formatarDistancia(distanciaMetros)}';
  String get textoArea => 'Área: ${formatarArea(areaM2)}';
}

// Soma dos trechos entre pontos seguidos.
double distanciaEmMetros(List<LatLng> pontos) {
  if (pontos.length < 2) return 0;
  final utm = pontos.map(latLngParaUtm).toList();
  var total = 0.0;
  for (var i = 0; i < utm.length - 1; i++) {
    final dx = utm[i + 1].x - utm[i].x;
    final dy = utm[i + 1].y - utm[i].y;
    total += sqrt(dx * dx + dy * dy);
  }
  return total;
}

// Área do polígono fechado (fórmula do laço).
double areaEmM2(List<LatLng> pontos) {
  if (pontos.length < 3) return 0;
  final utm = pontos.map(latLngParaUtm).toList();
  var soma = 0.0;
  for (var i = 0; i < utm.length; i++) {
    final p1 = utm[i];
    final p2 = utm[(i + 1) % utm.length];
    soma += p1.x * p2.y - p2.x * p1.y;
  }
  return soma.abs() / 2;
}

// "12.3 m" ou "1.25 km".
String formatarDistancia(double metros) => metros >= 1000
    ? '${(metros / 1000).toStringAsFixed(2)} km'
    : '${metros.toStringAsFixed(1)} m';

String formatarArea(double m2) => '${m2.toStringAsFixed(1)} m²';
