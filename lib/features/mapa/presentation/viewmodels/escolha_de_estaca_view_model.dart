import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../domain/entities/estaca_navegavel.dart';
import '../../domain/repositories/navegacao_estacas_repository.dart';

// "Ir para uma estaca": trecho → KM → estaca. Reabre no trecho e KM do
// destino atual, porque o comum é ir para a estaca vizinha.
class EscolhaDeEstacaViewModel extends ChangeNotifier with DescarteSeguro {
  EscolhaDeEstacaViewModel({
    required NavegacaoEstacasRepository repositorio,
    this.destinoAtual,
  }) : _repositorio = repositorio;

  final NavegacaoEstacasRepository _repositorio;
  final EstacaNavegavel? destinoAtual;

  bool _carregando = true;
  List<String> _trechos = const [];
  List<String> _kms = const [];
  List<EstacaNavegavel> _estacas = const [];
  String? _trecho;
  String? _km;

  bool get carregando => _carregando;
  List<String> get trechos => _trechos;
  List<String> get kms => _kms;
  List<EstacaNavegavel> get estacas => _estacas;
  String? get trecho => _trecho;
  String? get km => _km;

  // Nenhuma estaca com coordenada e KM nos arquivos do projeto.
  bool get semEstacas => !_carregando && _trechos.isEmpty;

  // Trecho sem KM (obra que não usa): as estacas vêm direto.
  bool get semKm => _kms.length == 1 && _kms.first.isEmpty;

  Future<void> carregar() async {
    final trechos = await _repositorio.trechos();
    mudar(() {
      _trechos = trechos;
      _carregando = false;
    });
    final atual = destinoAtual;
    if (atual != null && trechos.contains(atual.trecho)) {
      await escolherTrecho(atual.trecho);
      // Só se a pessoa não trocou de trecho enquanto carregava.
      if (_trecho == atual.trecho) await escolherKm(atual.km);
    }
  }

  Future<void> escolherTrecho(String trecho) async {
    mudar(() {
      _trecho = trecho;
      _km = null;
      _kms = const [];
      _estacas = const [];
    });
    final kms = await _repositorio.kms(trecho);
    // Trocou de trecho enquanto buscava: esta resposta já não vale.
    if (_trecho != trecho) return;
    mudar(() => _kms = kms);
    if (semKm) await escolherKm('');
  }

  Future<void> escolherKm(String km) async {
    final trecho = _trecho;
    if (trecho == null) return;
    mudar(() {
      _km = km;
      _estacas = const [];
    });
    final estacas = await _repositorio.estacas(trecho, km);
    // Trocou de trecho ou de KM enquanto buscava: esta resposta já não vale.
    if (_trecho != trecho || _km != km) return;
    mudar(() => _estacas = estacas);
  }
}
