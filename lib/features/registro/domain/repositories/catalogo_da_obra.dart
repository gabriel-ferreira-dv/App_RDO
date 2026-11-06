// O que dá para escolher no registro, das planilhas do projeto
// (SevNotaveis.csv e KMxEst.csv): trecho → KM, e atividade → serviço → passo.
abstract interface class CatalogoDaObra {
  Future<List<String>> trechos();
  Future<List<String>> kms(String trecho);
  Future<List<String>> atividades(String trecho);
  Future<List<String>> servicos(String trecho, String atividade);
  Future<List<String>> passos(String trecho, String atividade, String servico);
}
