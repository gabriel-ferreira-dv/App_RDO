import 'package:latlong2/latlong.dart';

// Estaca navegável: tem coordenada e KM.
class EstacaNavegavel {
  final String trecho;
  final String km;

  // Rótulo oficial do KMxEst ("EST. 1245"), o mesmo que aparece no formulário.
  final String rotulo;

  // Só os dígitos — usado para ordenar a lista na ordem do projeto.
  final int numero;
  final LatLng ponto;

  // Sentido da pista em trecho de pista dupla; null em pista simples.
  final String? via;

  const EstacaNavegavel({
    required this.trecho,
    required this.km,
    required this.rotulo,
    required this.numero,
    required this.ponto,
    this.via,
  });

  // "EST. 2115 • Via 01 Sul" (em pista dupla a via identifica a estaca).
  String get descricao => via == null ? rotulo : '$rotulo • $via';

  // "EST. 2115 • Via 01 Sul • C1 • KM 225"
  String get descricaoCompleta =>
      [descricao, trecho, if (km.isNotEmpty) 'KM $km'].join(' • ');
}
