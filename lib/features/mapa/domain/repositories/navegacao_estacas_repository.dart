import '../entities/estaca_navegavel.dart';

// Escolha de estaca para ir até ela no mapa: trecho → KM → estaca. Só entram
// estacas com coordenada e KM.
abstract interface class NavegacaoEstacasRepository {
  Future<List<String>> trechos();

  // KMs do trecho em ordem numérica. Trecho sem KM: um KM vazio ('').
  Future<List<String>> kms(String trecho);

  // Estacas do KM, na ordem do estaqueamento.
  Future<List<EstacaNavegavel>> estacas(String trecho, String km);
}
