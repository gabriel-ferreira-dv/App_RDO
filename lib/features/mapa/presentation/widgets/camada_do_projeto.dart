import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/dados_remotos.dart';
import '../../data/datasources/mapas_do_projeto.dart';

// Imagem de satélite (Esri). Acima do zoom 18 estica as imagens do 18.
TileLayer camadaDeSatelite() => TileLayer(
      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/'
          'World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.example.namer_app',
      maxNativeZoom: 18,
    );

// Camadas dos mapas do projeto que o usuário vê, para qualquer FlutterMap.
// Só aparecem a partir de [zoomMinimo]: de longe seriam centenas de peças.
// A chave liga cada camada ao seu mapa: quando a lista de mapas visíveis
// muda, nenhuma camada herda as peças de outro.
List<Widget> camadasDoProjeto({double zoomMinimo = 14}) => [
      for (final grade in mapasVisiveis())
        CamadaDoProjeto(grade,
            key: ValueKey(grade.pastaDasPecas), zoomMinimo: zoomMinimo),
    ];

// Um mapa do projeto sobre o satélite. Guarda as peças já vistas para não
// recarregar a cada movimento, e solta as que ficam longe da tela.
class CamadaDoProjeto extends StatefulWidget {
  final GradeDoMapa grade;

  // Abaixo deste zoom não carrega nada.
  final double zoomMinimo;

  const CamadaDoProjeto(this.grade, {super.key, this.zoomMinimo = 14});

  @override
  State<CamadaDoProjeto> createState() => _CamadaDoProjetoState();
}

class _CamadaDoProjetoState extends State<CamadaDoProjeto> {
  // Chaves "LL_C", o mesmo nome do arquivo sem a extensão.
  final Set<String> _carregadas = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizarPecas();
  }

  @override
  void didUpdateWidget(covariant CamadaDoProjeto anterior) {
    super.didUpdateWidget(anterior);
    final outraGrade = !identical(widget.grade, anterior.grade);
    // As peças guardadas são de outra grade (outro tamanho): não valem mais.
    if (outraGrade) _carregadas.clear();
    if (outraGrade || widget.zoomMinimo != anterior.zoomMinimo) {
      _sincronizarPecas();
    }
  }

  static ({int linha, int coluna}) _posicaoDa(String chave) {
    final sep = chave.indexOf('_');
    return (
      linha: int.parse(chave.substring(0, sep)),
      coluna: int.parse(chave.substring(sep + 1)),
    );
  }

  void _sincronizarPecas() {
    final camera = MapCamera.of(context);
    final grade = widget.grade;
    final visivel = camera.visibleBounds;

    // Mapa inteiro fora da tela (ou longe demais): solta tudo.
    if (camera.zoom < widget.zoomMinimo ||
        !envelopesSeCruzam(visivel, grade.envelope)) {
      if (_carregadas.isNotEmpty) setState(_carregadas.clear);
      return;
    }

    // Guarda as peças até 2× a área visível; o resto sai da memória.
    final dLat = (visivel.north - visivel.south) * 2;
    final dLon = (visivel.east - visivel.west) * 2;
    final guardar = LatLngBounds(
      LatLng(visivel.south - dLat, visivel.west - dLon),
      LatLng(visivel.north + dLat, visivel.east + dLon),
    );

    final antes = _carregadas.length;
    _carregadas.removeWhere((chave) {
      final p = _posicaoDa(chave);
      return !envelopesSeCruzam(guardar, grade.envelopeDaPeca(p.linha, p.coluna));
    });
    var mudou = _carregadas.length != antes;

    for (var l = 0; l < grade.linhas; l++) {
      for (var c = 0; c < grade.colunas; c++) {
        if (envelopesSeCruzam(visivel, grade.envelopeDaPeca(l, c)) &&
            _carregadas.add(GradeDoMapa.chaveDaPeca(l, c))) {
          mudou = true;
        }
      }
    }
    if (mudou) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_carregadas.isEmpty) return const SizedBox.shrink();
    final grade = widget.grade;
    return OverlayImageLayer(overlayImages: [
      for (final chave in _carregadas)
        if (_posicaoDa(chave) case (:final linha, :final coluna))
          RotatedOverlayImage(
            topLeftCorner: grade.canto(linha, coluna),
            bottomLeftCorner: grade.canto(linha + 1, coluna),
            bottomRightCorner: grade.canto(linha + 1, coluna + 1),
            // Peça baixada do servidor (.webp, bem menor que PNG).
            imageProvider: imagemOverlay(grade.pastaDasPecas, '$chave.webp'),
            gaplessPlayback: true,
            opacity: 0.8,
          ),
    ]);
  }
}
