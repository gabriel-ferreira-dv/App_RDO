import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../domain/entities/campos_do_registro.dart';
import '../../domain/entities/estaca_do_projeto.dart';
import '../../domain/entities/grupo_atividade.dart' show formatarQuantidade;
import '../../domain/entities/lista_de_estacas.dart';
import '../../domain/regras/correcao_de_registro.dart';
import '../../domain/regras/vias_estaqueamento.dart';
import '../../domain/repositories/catalogo_da_obra.dart';
import '../../domain/repositories/estaqueamento_repository.dart';

// Resultado de "Salvar correção".
sealed class ResultadoDaCorrecao {
  const ResultadoDaCorrecao();
}

class CorrecaoInvalida extends ResultadoDaCorrecao {
  final String erro;
  const CorrecaoInvalida(this.erro);
}

// Nada mudou: fecha sem gravar.
class SemMudanca extends ResultadoDaCorrecao {
  const SemMudanca();
}

class Corrigido extends ResultadoDaCorrecao {
  final CamposDoRegistro campos;
  const Corrigido(this.campos);
}

// Correção de um registro já feito: as mesmas listas em cascata do
// formulário de registro, começando do que foi gravado.
class EditarRegistroViewModel extends ChangeNotifier with DescarteSeguro {
  EditarRegistroViewModel({
    required CatalogoDaObra catalogo,
    required EstaqueamentoRepository estacas,
    required this.original,
  })  : _catalogo = catalogo,
        _estacas = estacas,
        trecho = _ouNulo(original.trecho),
        km = _ouNulo(original.km),
        via = _ouNulo(original.via),
        estacaInicial = _ouNulo(original.estacaInicial),
        estacaFinal = _ouNulo(original.estacaFinal),
        atividade = _ouNulo(original.atividade),
        servico = _ouNulo(original.servicoNotavel),
        passo = _ouNulo(original.servicoNotavelDetalhe),
        unidade = _ouNulo(original.unidade);

  final CatalogoDaObra _catalogo;
  final EstaqueamentoRepository _estacas;

  // Como o registro estava.
  final CamposDoRegistro original;

  String? trecho;
  String? km;
  String? via;
  String? estacaInicial;
  String? estacaFinal;
  String? atividade;
  String? servico;
  String? passo;
  String? unidade;

  List<String> trechos = [];
  List<String> kms = [];
  List<String> atividades = [];
  List<String> servicos = [];
  List<String> passos = [];
  List<EstacaDoProjeto> _estacasDaLista = [];
  bool carregando = true;

  static String? _ouNulo(String valor) => valor.trim().isEmpty ? null : valor;

  // Textos iniciais dos campos de digitar.
  String get quantidadeInicial => original.quantidade == null
      ? ''
      : formatarQuantidade(original.quantidade!);
  String get descricaoInicial => original.descricao;

  bool get pedeVia => trechoTemVia(trecho);
  bool get pedeEstaca => trechoTemEstaca(trecho);
  bool get pedeKm => trechoTemKm(trecho);
  List<String> get vias => [viaSul, viaNorte];

  ListaDeEstacas get _lista =>
      ListaDeEstacas(_estacasDaLista, km: km ?? '', usaKm: pedeKm);
  List<String> get rotulosDasEstacas => _lista.rotulos;
  bool get temEstacas => _estacasDaLista.isNotEmpty;
  String? rotuloNoCampo(String? rotulo) => _lista.rotuloNoCampo(rotulo);

  // ── Carregar ──────────────────────────────────────────────────────────────

  Future<void> carregar() async {
    final trechos = await _catalogo.trechos();
    final t = trecho;
    final a = atividade;
    final s = servico;
    final listas = t == null
        ? const <List<String>>[[], [], [], []]
        : await Future.wait([
            pedeKm ? _catalogo.kms(t) : Future.value(<String>[]),
            _catalogo.atividades(t),
            a == null ? Future.value(<String>[]) : _catalogo.servicos(t, a),
            a == null || s == null
                ? Future.value(<String>[])
                : _catalogo.passos(t, a, s),
          ]);
    final estacas = await _buscarEstacas();
    mudar(() {
      this.trechos = trechos;
      kms = listas[0];
      atividades = listas[1];
      servicos = listas[2];
      passos = listas[3];
      _estacasDaLista = estacas;
      carregando = false;
    });
  }

  Future<List<EstacaDoProjeto>> _buscarEstacas() async {
    final t = trecho;
    if (t == null || !pedeEstaca) return [];
    if (pedeVia && via == null) return [];
    // Sem KM, as estacas do trecho inteiro.
    if (!pedeKm) return _estacas.doTrecho(t, via: via);
    final k = km;
    if (k == null) return [];
    return _estacas.doKmEVizinhos(t, k, via: via);
  }

  // Estaca escolhida que ficou fora da lista nova sai.
  Future<void> _recarregarEstacas() async {
    final estacas = await _buscarEstacas();
    mudar(() {
      _estacasDaLista = estacas;
      if (_lista.porRotulo(estacaInicial) == null) estacaInicial = null;
      if (_lista.porRotulo(estacaFinal) == null) estacaFinal = null;
    });
  }

  // ── Escolhas ──────────────────────────────────────────────────────────────

  // Outro trecho invalida tudo o que vem depois.
  Future<void> escolherTrecho(String valor) async {
    mudar(() {
      trecho = valor;
      km = null;
      via = null;
      estacaInicial = null;
      estacaFinal = null;
      atividade = null;
      servico = null;
      passo = null;
      _estacasDaLista = [];
      servicos = [];
      passos = [];
    });
    final listas = await Future.wait([
      pedeKm ? _catalogo.kms(valor) : Future.value(<String>[]),
      _catalogo.atividades(valor),
    ]);
    mudar(() {
      kms = listas[0];
      atividades = listas[1];
    });
    if (!pedeKm) await _recarregarEstacas();
  }

  Future<void> escolherKm(String valor) async {
    mudar(() => km = valor);
    await _recarregarEstacas();
  }

  Future<void> escolherVia(String? valor) async {
    mudar(() => via = valor);
    await _recarregarEstacas();
  }

  void escolherEstacaInicial(String item) =>
      mudar(() => estacaInicial = _lista.rotuloEscolhido(item));

  void escolherEstacaFinal(String item) =>
      mudar(() => estacaFinal = _lista.rotuloEscolhido(item));

  Future<void> escolherAtividade(String valor) async {
    mudar(() {
      atividade = valor;
      servico = null;
      passo = null;
      passos = [];
    });
    final lista = await _catalogo.servicos(trecho!, valor);
    mudar(() => servicos = lista);
  }

  Future<void> escolherServico(String valor) async {
    mudar(() {
      servico = valor;
      passo = null;
    });
    final lista = await _catalogo.passos(trecho!, atividade!, valor);
    mudar(() => passos = lista);
  }

  void escolherPasso(String valor) => mudar(() => passo = valor);

  void escolherUnidade(String? valor) => mudar(() => unidade = valor);

  // ── Salvar ────────────────────────────────────────────────────────────────

  ResultadoDaCorrecao salvar({
    required String textoQuantidade,
    required String descricao,
  }) {
    final r = montarCamposCorrigidos(
      trecho: trecho,
      km: km,
      via: via,
      estacaInicial: _lista.porRotulo(estacaInicial),
      estacaFinal: _lista.porRotulo(estacaFinal),
      atividade: atividade,
      servico: servico,
      passo: passo,
      pedePasso: passos.isNotEmpty,
      textoQuantidade: textoQuantidade,
      unidade: unidade,
      descricao: descricao,
    );
    if (r.erro != null) return CorrecaoInvalida(r.erro!);
    final campos = r.campos!;
    return campos.mesmoQue(original) ? const SemMudanca() : Corrigido(campos);
  }
}
