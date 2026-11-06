import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localizacao_service.dart';
import '../../../../core/obra/config_da_obra.dart' show obraAtualNotifier;
import '../../data/datasources/permissao_mapas_service.dart';
import 'camada_do_projeto.dart';

// Zoom 19 mostra uns 72 m: dá para ler as marcações do mapa da obra.
const double _zoomDoMiniMapa = 19;

// Minimapa do carimbo: satélite, mapa da obra e o ponto, capturado fora da
// tela pela câmera.
Widget criarWidgetMiniMapa(LatLng centro) => MiniMapa(centro: centro);

class MiniMapa extends StatefulWidget {
  final LatLng centro;

  const MiniMapa({super.key, required this.centro});

  @override
  State<MiniMapa> createState() => _MiniMapaState();
}

class _MiniMapaState extends State<MiniMapa> {
  final MapController _controlador = MapController();
  late LatLng _centro = widget.centro;

  // `move` só vale com o mapa montado; antes, vale o `initialCenter`.
  bool _mapaPronto = false;

  @override
  void initState() {
    super.initState();
    // Acompanha o GPS sozinho, para o ponto ficar sempre no centro.
    LocalizacaoService.instancia.posicao.addListener(_acompanharPosicao);
    PermissaoMapasService.instancia.grupos.addListener(_redesenhar);
    obraAtualNotifier.addListener(_redesenhar);
  }

  void _redesenhar() {
    if (mounted) setState(() {});
  }

  void _acompanharPosicao() {
    final posicao = LocalizacaoService.instancia.posicao.value;
    if (posicao == null || !mounted) return;
    setState(() => _centro = posicao.ponto);
    if (_mapaPronto) _controlador.move(_centro, _zoomDoMiniMapa);
  }

  @override
  void didUpdateWidget(covariant MiniMapa anterior) {
    super.didUpdateWidget(anterior);
    if (widget.centro != anterior.centro) {
      _centro = widget.centro;
      if (_mapaPronto) _controlador.move(_centro, _zoomDoMiniMapa);
    }
  }

  @override
  void dispose() {
    LocalizacaoService.instancia.posicao.removeListener(_acompanharPosicao);
    PermissaoMapasService.instancia.grupos.removeListener(_redesenhar);
    obraAtualNotifier.removeListener(_redesenhar);
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controlador,
      options: MapOptions(
        initialCenter: _centro,
        initialZoom: _zoomDoMiniMapa,
        onMapReady: () => _mapaPronto = true,
        interactionOptions:
            const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        camadaDeSatelite(),
        ...camadasDoProjeto(),
        MarkerLayer(
          markers: [
            Marker(
              point: _centro,
              width: 22,
              height: 22,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(blurRadius: 4, color: Colors.black38),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
