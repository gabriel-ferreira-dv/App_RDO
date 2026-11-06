import '../entities/estaca_do_projeto.dart';

// Estacas do projeto, para as listas de estaca do registro e da correção.
abstract interface class EstaqueamentoRepository {
  // Estacas do [km] e dos KMs vizinhos, filtradas pela via, em ordem.
  Future<List<EstacaDoProjeto>> doKmEVizinhos(String trecho, String km,
      {String? via});

  // Todas as estacas do trecho (obra ou trecho sem KM), filtradas pela via.
  Future<List<EstacaDoProjeto>> doTrecho(String trecho, {String? via});
}
