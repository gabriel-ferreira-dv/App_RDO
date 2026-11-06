import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/dependencias.dart';
import '../../data/datasources/mapas_do_projeto.dart' show centroInicial;
import '../viewmodels/mapa_view_model.dart';
import '../widgets/camada_do_projeto.dart';
import '../widgets/folha_de_navegacao.dart';
import '../widgets/paineis_do_mapa.dart';

// Aba Mapa: satélite, mapas do projeto, onde a pessoa está, ir até uma
// estaca e medir. O estado fica no MapaViewModel; aqui o desenho e o
// controle da câmera do mapa.
class MapPage extends StatefulWidget {
  // Para testes: um ViewModel já montado no lugar do padrão.
  final MapaViewModel? viewModel;

  const MapPage({super.key, this.viewModel});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapaViewModel _vm = widget.viewModel ?? Dependencias.mapa();
  final _mapa = MapController();
  final _centro = centroInicial;

  // Última posição para onde o mapa foi levado seguindo a pessoa.
  LatLng? _seguida;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_seguirAPessoa);
    Dependencias.iniciarGps();
  }

  @override
  void dispose() {
    _vm.removeListener(_seguirAPessoa);
    _vm.dispose();
    _mapa.dispose();
    super.dispose();
  }

  // Nova posição do GPS com o mapa seguindo: leva o mapa até ela.
  void _seguirAPessoa() {
    final posicao = _vm.posicao;
    if (!_vm.seguindoUsuario || posicao == null || posicao == _seguida) return;
    _seguida = posicao;
    _mapa.move(posicao, _mapa.camera.zoom);
  }

  void _voltarParaMim() {
    final posicao = _vm.voltarParaMinhaLocalizacao();
    if (posicao == null) return;
    _seguida = posicao;
    _mapa.move(posicao, _mapa.camera.zoom);
  }

  Future<void> _navegar() async {
    final estaca =
        await escolherEstacaParaNavegar(context, destinoAtual: _vm.destino);
    if (estaca == null || !mounted) return;
    _vm.escolherDestino(estaca);
    _mapa.move(estaca.ponto, 20);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Stack(
        children: [
          FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: _centro,
              initialZoom: 20,
              minZoom: 18,
              maxZoom: 22,
              onTap: (_, ponto) => _vm.tocouNoMapa(ponto),
              onPositionChanged: (_, porGesto) {
                if (porGesto) _vm.moveuPorGesto();
              },
            ),
            children: [
              camadaDeSatelite(),
              ...camadasDoProjeto(),
              ..._camadasDaPessoa(),
              ..._camadasDaMedicao(),
              ..._camadasDoDestino(),
            ],
          ),
          if (_vm.medindo)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: PainelDeMedicao(
                medicao: _vm.medicao,
                aoDesfazer: _vm.desfazerPonto,
                aoLimpar: _vm.limparMedicao,
              ),
            ),
          if (!_vm.medindo && _vm.destino != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: PainelDeDestino(
                titulo: _vm.destino!.descricaoCompleta,
                distancia: _vm.distanciaAteODestino,
                aoTrocar: _navegar,
                aoEncerrar: _vm.limparDestino,
              ),
            ),
          Positioned(
            right: 12,
            bottom: _vm.medindo
                ? 180
                : _vm.destino != null
                    ? 140
                    : 12,
            child: BotoesDoMapa(
              medindo: _vm.medindo,
              comDestino: _vm.destino != null,
              seguindoUsuario: _vm.seguindoUsuario,
              aoNavegar: _navegar,
              aoVoltarParaMim: _voltarParaMim,
              aoAlternarMedicao: _vm.alternarMedicao,
            ),
          ),
        ],
      ),
    );
  }

  // Onde a pessoa está, com o círculo da precisão do GPS.
  List<Widget> _camadasDaPessoa() {
    final posicao = _vm.posicao;
    if (posicao == null) return const [];
    return [
      if (_vm.precisaoMetros > 0)
        CircleLayer(circles: [
          CircleMarker(
            point: posicao,
            radius: _vm.precisaoMetros,
            useRadiusInMeter: true,
            color: Colors.blue.withValues(alpha: 0.15),
            borderColor: Colors.blue.withValues(alpha: 0.5),
            borderStrokeWidth: 1,
          ),
        ]),
      MarkerLayer(markers: [
        Marker(
          point: posicao,
          width: 6,
          height: 6,
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 243, 33, 33),
              border: Border.all(color: Colors.red, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black38)],
            ),
          ),
        ),
      ]),
    ];
  }

  // Pontos, linha e área marcados.
  List<Widget> _camadasDaMedicao() {
    final medicao = _vm.medicao;
    return [
      if (medicao.temArea)
        PolygonLayer(polygons: [
          Polygon(
            points: medicao.pontos,
            color: Colors.amber.withValues(alpha: 0.25),
            borderColor: Colors.amber,
            borderStrokeWidth: 3,
          ),
        ]),
      if (medicao.temLinha)
        PolylineLayer(polylines: [
          Polyline(points: medicao.pontos, color: Colors.amber, strokeWidth: 3),
        ]),
      if (!medicao.vazia)
        MarkerLayer(markers: [
          for (final p in medicao.pontos)
            Marker(
              point: p,
              width: 14,
              height: 14,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ]),
    ];
  }

  // A estaca escolhida e a linha até ela (mostra a direção).
  List<Widget> _camadasDoDestino() {
    final destino = _vm.destino;
    if (destino == null) return const [];
    final posicao = _vm.posicao;
    return [
      if (posicao != null)
        PolylineLayer(polylines: [
          Polyline(
            points: [posicao, destino.ponto],
            color: Colors.lightBlueAccent,
            strokeWidth: 3,
            pattern: StrokePattern.dashed(segments: const [12, 8]),
          ),
        ]),
      MarkerLayer(markers: [
        Marker(
          point: destino.ponto,
          width: 34,
          height: 34,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
            ),
            child: const Icon(Icons.place, size: 18, color: Colors.white),
          ),
        ),
      ]),
    ];
  }
}
