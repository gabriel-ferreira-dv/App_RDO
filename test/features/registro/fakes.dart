import 'package:namer_app/features/registro/domain/entities/estaca_do_projeto.dart';
import 'package:namer_app/features/registro/domain/entities/foto_com_contexto.dart';
import 'package:namer_app/features/registro/domain/entities/registro.dart';
import 'package:namer_app/features/registro/domain/entities/sugestao_gps.dart';
import 'package:namer_app/features/registro/domain/repositories/catalogo_da_obra.dart';
import 'package:namer_app/features/registro/domain/repositories/ditado.dart';
import 'package:namer_app/features/registro/domain/repositories/estaqueamento_repository.dart';
import 'package:namer_app/features/registro/domain/repositories/localizacao_na_obra.dart';
import 'package:namer_app/features/registro/domain/repositories/registro_repository.dart';
import 'package:namer_app/features/registro/presentation/viewmodels/formulario_de_registro.dart';

// Planilhas falsas: trecho → KMs e atividades; atividade → serviços; serviço
// → passos.
class CatalogoFalso implements CatalogoDaObra {
  List<String> listaDeTrechos = ['C1', 'PATIO DE VIGAS'];
  Map<String, List<String>> kmsPorTrecho = {
    'C1': ['224', '225', '226'],
  };
  Map<String, List<String>> atividadesPorTrecho = {
    'C1': ['Terraplanagem', 'Drenagem'],
    'PATIO DE VIGAS': ['Civil'],
  };
  Map<String, List<String>> servicosPorAtividade = {
    'Terraplanagem': ['COMPACTAÇÃO DE ATERRO'],
  };
  Map<String, List<String>> passosPorServico = {
    'COMPACTAÇÃO DE ATERRO': ['Aterro na saia', 'Acabamento'],
  };

  @override
  Future<List<String>> trechos() async => listaDeTrechos;

  @override
  Future<List<String>> kms(String trecho) async => kmsPorTrecho[trecho] ?? [];

  @override
  Future<List<String>> atividades(String trecho) async =>
      atividadesPorTrecho[trecho] ?? [];

  @override
  Future<List<String>> servicos(String trecho, String atividade) async =>
      servicosPorAtividade[atividade] ?? [];

  @override
  Future<List<String>> passos(
          String trecho, String atividade, String servico) async =>
      passosPorServico[servico] ?? [];
}

EstacaDoProjeto estacaDe(int numero, String km,
        {String trecho = 'C1', String? via = 'Via 02 Norte'}) =>
    EstacaDoProjeto(
        trecho: trecho, numero: numero, rotulo: '$numero', km: km, via: via);

// Estacas do C1, KMs 224 a 226, na via norte.
class EstacasFalsas implements EstaqueamentoRepository {
  List<EstacaDoProjeto> todas = [
    estacaDe(1110, '224'),
    estacaDe(1115, '225'),
    estacaDe(1120, '225'),
    estacaDe(1125, '226'),
  ];

  @override
  Future<List<EstacaDoProjeto>> doTrecho(String trecho, {String? via}) async =>
      [
        for (final e in todas)
          if (e.trecho == trecho && (via == null || e.via == via)) e,
      ];

  @override
  Future<List<EstacaDoProjeto>> doKmEVizinhos(String trecho, String km,
      {String? via}) async {
    final n = int.parse(km);
    return [
      for (final e in await doTrecho(trecho, via: via))
        if (kmNoIntervalo(e.km, '${n - kmsVizinhos}', '${n + kmsVizinhos}')) e,
    ];
  }
}

class LocalizacaoFalsa implements LocalizacaoNaObra {
  ResultadoSugestaoGps resultado =
      ResultadoSugestaoGps.falha('Ative a localização (GPS) do aparelho');

  @override
  Future<ResultadoSugestaoGps> sugerir() async => resultado;
}

// Banco falso: guarda o que seria gravado.
class RegistrosFalsos implements RegistroRepository {
  final criados = <Map<String, Object?>>[];
  List<Registro> anteriores = [];

  @override
  Future<int> criarRegistro({
    required int usuarioId,
    required String trecho,
    required String km,
    String kmFinal = '',
    required String via,
    required String atividade,
    required String estacaInicial,
    required String estacaFinal,
    required String servicoNotavel,
    required String servicoNotavelDetalhe,
    double? quantidade,
    String unidade = '',
    String emNomeDeMatricula = '',
    String emNomeDeNome = '',
    required String descricao,
  }) async {
    criados.add({
      'usuarioId': usuarioId,
      'trecho': trecho,
      'km': km,
      'kmFinal': kmFinal,
      'via': via,
      'atividade': atividade,
      'estacaInicial': estacaInicial,
      'estacaFinal': estacaFinal,
      'servico': servicoNotavel,
      'passo': servicoNotavelDetalhe,
      'quantidade': quantidade,
      'unidade': unidade,
      'descricao': descricao,
    });
    return criados.length;
  }

  @override
  Future<void> adicionarFoto({
    required int registroId,
    required String caminhoArquivo,
    double? latitude,
    double? longitude,
    String caminhoOriginal = '',
    String caminhoMinimapa = '',
    DateTime? criadoEm,
  }) async {}

  // Simula erro do banco ao listar os registros anteriores.
  bool falharAoListar = false;

  @override
  Future<List<Registro>> listarRegistros(int usuarioId) async {
    if (falharAoListar) throw StateError('banco indisponível');
    return anteriores;
  }

  @override
  Future<List<FotoComContexto>> listarFotosComContexto(int usuarioId,
          {String? desde}) async =>
      [];
}

// Ditado falso: [disponivel] diz se o aparelho tem reconhecimento de voz;
// [falar] simula o que a pessoa ditou.
class DitadoFalso implements Ditado {
  bool disponivel = true;
  bool ouvindo = false;
  void Function(String texto)? _aoReconhecer;
  void Function()? _aoTerminar;

  void falar(String texto, {bool fim = false}) {
    _aoReconhecer?.call(texto);
    if (fim) _aoTerminar?.call();
  }

  @override
  Future<bool> iniciar() async => disponivel;

  @override
  Future<void> ouvir({
    required void Function(String texto) aoReconhecer,
    void Function()? aoTerminar,
  }) async {
    ouvindo = true;
    _aoReconhecer = aoReconhecer;
    _aoTerminar = aoTerminar;
  }

  @override
  Future<void> parar() async => ouvindo = false;

  @override
  void cancelar() => ouvindo = false;
}

// Formulário com tudo falso; passe um falso para controlar o que ele devolve.
FormularioDeRegistro formularioDeTeste({
  CatalogoFalso? catalogo,
  EstacasFalsas? estacas,
  LocalizacaoFalsa? localizacao,
  RegistrosFalsos? registros,
  DitadoFalso? ditado,
}) =>
    FormularioDeRegistro(
      catalogo: catalogo ?? CatalogoFalso(),
      estacas: estacas ?? EstacasFalsas(),
      localizacao: localizacao ?? LocalizacaoFalsa(),
      registros: registros ?? RegistrosFalsos(),
      ditado: ditado ?? DitadoFalso(),
    );
