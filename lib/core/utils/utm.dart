import 'package:latlong2/latlong.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;

// Fuso UTM (SIRGAS 2000) em que estão as coordenadas do projeto.
class ZonaUtm {
  final int fuso;
  final bool sul;

  const ZonaUtm(this.fuso, {this.sul = true});

  String get nome => 'UTM$fuso${sul ? 'S' : 'N'}';

  String get definicao => '+proj=utm +zone=$fuso ${sul ? '+south ' : ''}'
      '+ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs';

  @override
  bool operator ==(Object other) =>
      other is ZonaUtm && other.fuso == fuso && other.sul == sul;

  @override
  int get hashCode => Object.hash(fuso, sul);
}

// Fuso da obra atual; quem troca é a configuração da obra (ver
// core/obra/config_da_obra.dart).
ZonaUtm zonaUtmAtual = const ZonaUtm(24);

proj4.Projection _projecao(ZonaUtm zona) =>
    proj4.Projection.get(zona.nome) ??
    proj4.Projection.add(zona.nome, zona.definicao);

LatLng utmParaLatLng(double e, double n, {ZonaUtm? zona}) {
  final wgs84 = proj4.Projection.get('EPSG:4326')!;
  final pt =
      _projecao(zona ?? zonaUtmAtual).transform(wgs84, proj4.Point(x: e, y: n));
  return LatLng(pt.y, pt.x);
}

proj4.Point latLngParaUtm(LatLng ll, {ZonaUtm? zona}) {
  final wgs84 = proj4.Projection.get('EPSG:4326')!;
  return wgs84.transform(_projecao(zona ?? zonaUtmAtual),
      proj4.Point(x: ll.longitude, y: ll.latitude));
}
