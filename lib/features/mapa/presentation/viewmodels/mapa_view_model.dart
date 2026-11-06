import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localizacao_service.dart' show PosicaoGps;
import '../../domain/entities/estaca_navegavel.dart';
import '../../domain/regras/medicao.dart';

// Estado da aba Mapa: onde a pessoa está (GPS filtrado), se o mapa a segue,
// a estaca de destino e a medição. Mover a câmera do mapa é da tela.
class MapaViewModel extends ChangeNotifier {
  MapaViewModel({
    required ValueListenable<PosicaoGps?> posicao,
    required Listenable mudancasNosMapas,
  })  : _gps = posicao,
        _mapas = mudancasNosMapas {
    _gps.addListener(_aoMoverGps);
    // Permissão e config da obra podem mudar com a tela aberta.
    _mapas.addListener(notifyListeners);
    _aoMoverGps();
  }

  final ValueListenable<PosicaoGps?> _gps;
  final Listenable _mapas;

  LatLng? _posicao;
  double _precisaoMetros = 0;
  bool _seguindoUsuario = true;
  EstacaNavegavel? _destino;
  bool _medindo = false;
  final List<LatLng> _pontos = [];

  LatLng? get posicao => _posicao;
  double get precisaoMetros => _precisaoMetros;
  bool get seguindoUsuario => _seguindoUsuario;
  EstacaNavegavel? get destino => _destino;
  bool get medindo => _medindo;
  Medicao get medicao => Medicao(List.unmodifiable(_pontos));

  // "Você está a 120.4 m daqui"; null sem GPS ou sem destino.
  String? get distanciaAteODestino {
    final p = _posicao;
    final d = _destino;
    if (p == null || d == null) return null;
    return 'Você está a ${formatarDistancia(distanciaEmMetros([p, d.ponto]))} '
        'daqui';
  }

  void _aoMoverGps() {
    final nova = _gps.value;
    if (nova == null) return;
    _posicao = nova.ponto;
    _precisaoMetros = nova.precisaoMetros;
    notifyListeners();
  }

  // ── Seguir a pessoa ───────────────────────────────────────────────────────

  // A pessoa arrastou o mapa: para de seguir o GPS.
  void moveuPorGesto() {
    if (!_seguindoUsuario) return;
    _seguindoUsuario = false;
    notifyListeners();
  }

  // Volta a seguir; devolve para onde mover (null sem GPS ainda).
  LatLng? voltarParaMinhaLocalizacao() {
    _seguindoUsuario = true;
    notifyListeners();
    return _posicao;
  }

  // ── Destino ───────────────────────────────────────────────────────────────

  void escolherDestino(EstacaNavegavel estaca) {
    _destino = estaca;
    _seguindoUsuario = false;
    notifyListeners();
  }

  void limparDestino() {
    _destino = null;
    notifyListeners();
  }

  // ── Medição ───────────────────────────────────────────────────────────────

  void alternarMedicao() {
    _medindo = !_medindo;
    notifyListeners();
  }

  // Toque no mapa: vira ponto da medição, se ela estiver ligada.
  void tocouNoMapa(LatLng ponto) {
    if (!_medindo) return;
    _pontos.add(ponto);
    notifyListeners();
  }

  void desfazerPonto() {
    if (_pontos.isEmpty) return;
    _pontos.removeLast();
    notifyListeners();
  }

  void limparMedicao() {
    _pontos.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _gps.removeListener(_aoMoverGps);
    _mapas.removeListener(notifyListeners);
    super.dispose();
  }
}
