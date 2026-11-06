import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../mapa/presentation/widgets/camada_do_projeto.dart'
    show camadaDeSatelite, camadasDoProjeto;
import '../../domain/entities/registro_da_equipe.dart';
import '../viewmodels/mapa_avanco_view_model.dart';

// O mapa com os registros pintados sobre as estacas: linha quando o registro
// cobre várias estacas, ponto quando é uma só. A cor é a do serviço; o que é
// dos últimos 7 dias fica forte.
class MapaDoAvanco extends StatelessWidget {
  final MapController controlador;
  final LayerHitNotifier<RegistroDaEquipe> toque;
  final List<TracoDoAvanco> tracos;
  final List<List<LatLng>> eixos;
  final ValueChanged<List<RegistroDaEquipe>> aoTocar;
  final VoidCallback aoFicarPronto;

  const MapaDoAvanco({
    super.key,
    required this.controlador,
    required this.toque,
    required this.tracos,
    required this.eixos,
    required this.aoTocar,
    required this.aoFicarPronto,
  });

  static const _folga = EdgeInsets.fromLTRB(40, 40, 40, 220);

  @override
  Widget build(BuildContext context) {
    final linhas = <Polyline<RegistroDaEquipe>>[];
    final pontos = <Marker>[];
    for (final t in tracos) {
      final cor = Color(t.cor);
      final corDoTraco = t.recente ? cor : cor.withValues(alpha: 0.55);
      if (t.pontos.length == 1) {
        pontos.add(Marker(
          point: t.pontos.first,
          width: 18,
          height: 18,
          child: GestureDetector(
            onTap: () => aoTocar([t.registro]),
            child: Container(
              decoration: BoxDecoration(
                color: corDoTraco,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ));
        continue;
      }
      linhas.add(Polyline(
        points: t.pontos,
        color: corDoTraco,
        strokeWidth: t.recente ? 7 : 5,
        borderColor: Colors.white.withValues(alpha: t.recente ? 0.9 : 0.5),
        borderStrokeWidth: 1.5,
        strokeCap: StrokeCap.round,
        hitValue: t.registro,
      ));
    }

    // Sem nada filtrado: mostra a obra inteira.
    final inicio = tracos.isNotEmpty
        ? [for (final t in tracos) ...t.pontos]
        : [for (final eixo in eixos) ...eixo];

    return FlutterMap(
      mapController: controlador,
      options: MapOptions(
        initialCameraFit: inicio.length > 1
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(inicio),
                padding: _folga,
                maxZoom: 18,
              )
            : null,
        initialCenter: inicio.isEmpty ? const LatLng(-19.95, -40.40) : inicio.first,
        initialZoom: 14,
        minZoom: 10,
        maxZoom: 20,
        onMapReady: aoFicarPronto,
      ),
      children: [
        camadaDeSatelite(),
        // Ortofoto e desenho do projeto, os da aba Mapa. Só de perto: de
        // longe seriam centenas de peças de uma vez.
        ...camadasDoProjeto(zoomMinimo: 17),
        // O eixo do projeto, fino, para dar referência onde nada foi feito.
        PolylineLayer(
          polylines: [
            for (final eixo in eixos)
              Polyline(
                points: eixo,
                color: Colors.white.withValues(alpha: 0.35),
                strokeWidth: 2,
              ),
          ],
        ),
        GestureDetector(
          onTap: () => aoTocar(toque.value?.hitValues ?? const []),
          child: PolylineLayer<RegistroDaEquipe>(
            hitNotifier: toque,
            polylines: linhas,
          ),
        ),
        MarkerLayer(markers: pontos),
      ],
    );
  }
}

// Enquadra o mapa nos [pontos]: um só, aproxima; vários, cabe todos.
void enquadrarNoMapa(MapController controlador, List<LatLng> pontos) {
  if (pontos.isEmpty) return;
  if (pontos.length == 1) {
    controlador.move(pontos.first, 17);
    return;
  }
  controlador.fitCamera(CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(pontos),
    padding: MapaDoAvanco._folga,
    maxZoom: 18,
  ));
}
