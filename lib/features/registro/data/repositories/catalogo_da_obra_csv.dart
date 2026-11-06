import '../../domain/repositories/catalogo_da_obra.dart';
import '../datasources/csv_dados_datasource.dart' as csv;

// As listas do registro lidas das planilhas do projeto (as que vêm no APK ou
// as baixadas em Atualizações).
class CatalogoDaObraCsv implements CatalogoDaObra {
  const CatalogoDaObraCsv();

  @override
  Future<List<String>> trechos() => csv.carregarTrechos();

  // Coluna do KM no KMxEst.csv, filtrada pelo trecho.
  @override
  Future<List<String>> kms(String trecho) => csv.carregarKmEst(3, 0, trecho);

  @override
  Future<List<String>> atividades(String trecho) =>
      csv.carregarAtividades(trecho);

  @override
  Future<List<String>> servicos(String trecho, String atividade) =>
      csv.carregarServicosNotaveis(trecho, atividade);

  @override
  Future<List<String>> passos(
          String trecho, String atividade, String servico) =>
      csv.carregarPassosDoServico(trecho, atividade, servico);
}
