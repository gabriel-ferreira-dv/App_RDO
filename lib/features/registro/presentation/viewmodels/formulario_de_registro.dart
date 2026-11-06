import 'package:flutter/material.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../supervisor/domain/entities/encarregado_da_equipe.dart';
import '../../domain/entities/estaca_do_projeto.dart';
import '../../domain/entities/lista_de_estacas.dart';
import '../../domain/entities/registro.dart';
import '../../domain/entities/sugestao_gps.dart';
import '../../domain/regras/atividades_descricoes.dart';
import '../../domain/regras/vias_estaqueamento.dart';
import '../../domain/repositories/catalogo_da_obra.dart';
import '../../domain/repositories/ditado.dart';
import '../../domain/repositories/estaqueamento_repository.dart';
import '../../domain/repositories/localizacao_na_obra.dart';
import '../../domain/repositories/registro_repository.dart';

// Etapas do registro; a terceira (fotos) é a câmera.
enum EtapaDoRegistro { local, servico }

// O que a câmera precisa saber do registro recém-criado.
typedef RegistroParaFotos = ({
  int registroId,
  String trecho,
  String faixaDeKm,
  String estacaInicial,
  String estacaFinal,
  String via,
  String descricao,
  String servico,
  String passo,
});

// Estado e regras do formulário de registro: o que foi escolhido, as listas
// em cascata (trecho → KM → via → estacas, ou trecho → via → estacas na obra
// sem KM; atividade → serviço → passo), a
// conferência de cada etapa e a gravação. A tela (RegistroPage) só desenha e
// chama estes métodos.
//
// Fica na casca do app (HomePage), e não na tela: trocar de aba e voltar não
// perde o que já foi preenchido.
class FormularioDeRegistro extends ChangeNotifier with DescarteSeguro {
  FormularioDeRegistro({
    required CatalogoDaObra catalogo,
    required EstaqueamentoRepository estacas,
    required LocalizacaoNaObra localizacao,
    required RegistroRepository registros,
    required Ditado ditado,
  })  : _catalogo = catalogo,
        _estacas = estacas,
        _localizacao = localizacao,
        _registros = registros,
        _ditado = ditado;

  final CatalogoDaObra _catalogo;
  final EstaqueamentoRepository _estacas;
  final LocalizacaoNaObra _localizacao;
  final RegistroRepository _registros;
  final Ditado _ditado;

  EtapaDoRegistro etapa = EtapaDoRegistro.local;

  // ── Supervisor lançando em nome de um encarregado ─────────────────────────
  List<EncarregadoDaEquipe> equipe = [];
  // null = em nome próprio.
  EncarregadoDaEquipe? registrandoPara;

  // ── Local ─────────────────────────────────────────────────────────────────
  String? trecho;
  String? km;
  String? via;
  String? estacaInicial;
  String? estacaFinal;

  List<String> trechos = [];
  List<String> kms = [];
  // Estacas do KM escolhido e dos vizinhos (ou do trecho inteiro, sem KM),
  // filtradas pela via.
  List<EstacaDoProjeto> estacasDoIntervalo = [];

  bool buscandoGps = false;

  // ── Serviço ───────────────────────────────────────────────────────────────
  String? atividade;
  String? servico;
  String? passo;
  String? unidade;

  List<String> atividades = [];
  List<String> servicos = [];
  List<String> passos = [];

  final descricao = TextEditingController();
  final quantidade = TextEditingController();

  // ── Ditado da descrição ───────────────────────────────────────────────────
  bool ditando = false;
  String _textoAntesDoDitado = '';

  // ── Regras que dependem do trecho ─────────────────────────────────────────

  // Se o trecho pede a via (os Contornos não pedem).
  bool get pedeVia => trechoTemVia(trecho);

  // Se o trecho pede estaca (as áreas de apoio não pedem).
  bool get pedeEstaca => trechoTemEstaca(trecho);

  // Se o trecho pede o KM (obra sem KM não pede: estaca direto do trecho).
  bool get pedeKm => trechoTemKm(trecho);

  bool get podeEscolherEstaca =>
      (pedeKm ? km != null : trecho != null) && (!pedeVia || via != null);

  // Explicação da atividade escolhida (do guia das atividades).
  String? get descricaoDaAtividadeEscolhida => descricaoDaAtividade(atividade);

  // "C1 · km 225 · est. 1115 – 1120", para o resumo no topo da etapa 2.
  String get resumoDoLocal {
    final inicio = _lista.porRotulo(estacaInicial)?.km ?? km ?? '';
    final fim = _lista.porRotulo(estacaFinal)?.km ?? inicio;
    return [
      if (trecho != null) trecho!,
      if (pedeKm && km != null)
        'km ${faixaDeKm(inicio, fim == inicio ? '' : fim)}',
      if (pedeEstaca && estacaInicial != null)
        estacaFinal == null || estacaFinal == estacaInicial
            ? 'est. $estacaInicial'
            : 'est. $estacaInicial – $estacaFinal',
    ].join(' · ');
  }

  // ── Listas de estaca ──────────────────────────────────────────────────────

  // As estacas do intervalo como aparecem nas listas (com o KM ao lado nas
  // de outro KM).
  ListaDeEstacas get _lista =>
      ListaDeEstacas(estacasDoIntervalo, km: km ?? '', usaKm: pedeKm);

  List<String> get rotulosDoIntervalo => _lista.rotulos;

  // Como a estaca [rotulo] aparece no campo.
  String? rotuloNoCampo(String? rotulo) => _lista.rotuloNoCampo(rotulo);

  // Posição da estaca [rotulo] na lista; null se não está nela.
  int? indiceDaEstaca(String? rotulo) => _lista.indiceDe(rotulo);

  // Posição da primeira estaca do KM escolhido, onde a lista abre.
  int? get indiceDoKm => _lista.indiceDoKm;

  // ── Escolhas ──────────────────────────────────────────────────────────────

  Future<void> carregarTrechos() async {
    trechos = await _catalogo.trechos();
    notifyListeners();
  }

  void escolherAutoria(String? matricula) {
    registrandoPara = matricula == null
        ? null
        : equipe.firstWhere((e) => e.matricula == matricula);
    notifyListeners();
  }

  // Equipe e perfil vêm da casca, que revalida o perfil ao abrir.
  void definirEquipe(List<EncarregadoDaEquipe> novaEquipe,
      {required bool ehSupervisor}) {
    equipe = ehSupervisor ? novaEquipe : [];
    if (!ehSupervisor) registrandoPara = null;
    notifyListeners();
  }

  Future<void> escolherTrecho(String valor) async {
    trecho = valor;
    km = null;
    // A via é de cada trecho: zera ao trocar.
    via = null;
    _limparDaEstacaEmDiante();
    atividades = [];
    kms = [];
    notifyListeners();
    if (pedeKm) {
      kms = await _catalogo.kms(valor);
      notifyListeners();
      return;
    }
    // Sem KM, o trecho já basta para as atividades e as estacas.
    atividades = await _catalogo.atividades(valor);
    notifyListeners();
    await _recarregarEstacas();
  }

  // Trocar o KM invalida atividade, estacas e serviço já escolhidos.
  Future<void> escolherKm(String valor) async {
    km = valor;
    _limparDaEstacaEmDiante();
    notifyListeners();
    atividades = await _catalogo.atividades(trecho!);
    notifyListeners();
    await _recarregarEstacas();
  }

  // Outra pista, outra numeração: zera as estacas.
  Future<void> escolherVia(String? valor) async {
    via = valor;
    estacaInicial = null;
    estacaFinal = null;
    estacasDoIntervalo = [];
    notifyListeners();
    await _recarregarEstacas();
  }

  void escolherEstacaInicial(String item) {
    estacaInicial = _lista.rotuloEscolhido(item);
    notifyListeners();
  }

  void escolherEstacaFinal(String item) {
    estacaFinal = _lista.rotuloEscolhido(item);
    notifyListeners();
  }

  // Trocar a atividade invalida o serviço e o passo já escolhidos.
  Future<void> escolherAtividade(String valor) async {
    if (valor == atividade) return;
    atividade = valor;
    servico = null;
    passo = null;
    servicos = [];
    passos = [];
    notifyListeners();
    servicos = await _catalogo.servicos(trecho!, valor);
    notifyListeners();
  }

  // Trocar o serviço invalida o passo já escolhido.
  Future<void> escolherServico(String valor) async {
    servico = valor;
    passo = null;
    passos = [];
    notifyListeners();
    passos = await _catalogo.passos(trecho!, atividade!, valor);
    notifyListeners();
  }

  void escolherPasso(String valor) {
    passo = valor;
    notifyListeners();
  }

  void escolherUnidade(String? valor) {
    unidade = valor;
    notifyListeners();
  }

  void _limparDaEstacaEmDiante() {
    atividade = null;
    estacaInicial = null;
    estacaFinal = null;
    servico = null;
    passo = null;
    estacasDoIntervalo = [];
    servicos = [];
    passos = [];
  }

  // Recarrega as estacas do KM e dos vizinhos (ou do trecho, sem KM),
  // filtradas pela via. Estaca escolhida que ficou fora da lista nova sai.
  Future<void> _recarregarEstacas() async {
    final t = trecho;
    final k = km;
    if (t == null || (pedeKm && k == null) || !pedeEstaca) return;
    // Só espera a via onde ela é perguntada.
    if (pedeVia && via == null) return;
    estacasDoIntervalo = await _estacasDoLocal(t, pedeKm ? k : null, via);
    if (_lista.porRotulo(estacaInicial) == null) estacaInicial = null;
    if (_lista.porRotulo(estacaFinal) == null) estacaFinal = null;
    notifyListeners();
  }

  // Estacas para as listas: do KM e vizinhos, ou do trecho inteiro quando
  // [km] é null (sem KM).
  Future<List<EstacaDoProjeto>> _estacasDoLocal(
          String trecho, String? km, String? via) =>
      km == null
          ? _estacas.doTrecho(trecho, via: via)
          : _estacas.doKmEVizinhos(trecho, km, via: via);

  // ── Atalhos de preenchimento ──────────────────────────────────────────────

  // Preenche trecho, KM, estaca e via pela estaca do projeto mais perto.
  // Devolve a frase para mostrar (onde a pessoa está, ou o erro).
  Future<String> preencherPelaLocalizacao() async {
    buscandoGps = true;
    notifyListeners();
    final resultado = await _localizacao.sugerir();
    buscandoGps = false;
    final sugestao = resultado.sugestao;
    if (sugestao == null) {
      notifyListeners();
      return resultado.erro ?? 'Não foi possível usar a localização';
    }

    final comKm = trechoTemKm(sugestao.trecho) && sugestao.km.isNotEmpty;
    final listas = await Future.wait([
      comKm ? _catalogo.kms(sugestao.trecho) : Future.value(<String>[]),
      _catalogo.atividades(sugestao.trecho),
    ]);
    final estacas = await _estacasDoLocal(
        sugestao.trecho, comKm ? sugestao.km : null, sugestao.via);

    trecho = sugestao.trecho;
    km = comKm ? sugestao.km : null;
    // Em pista dupla a estaca já diz a via; senão o encarregado escolhe.
    via = sugestao.via ?? via;
    _limparDaEstacaEmDiante();
    estacaInicial = sugestao.estaca;
    kms = listas[0];
    atividades = listas[1];
    estacasDoIntervalo = estacas;
    notifyListeners();

    final distancia = formatarDistanciaMetros(sugestao.distanciaMetros);
    final noKm = comKm ? ', KM ${sugestao.km}' : '';
    return trechoTemEstaca(sugestao.trecho)
        ? 'Você está a $distancia da Estaca ${sugestao.estaca} no Trecho '
            '${sugestao.trecho}$noKm'
        : 'Você está a $distancia do ${sugestao.trecho}$noKm';
  }

  // Copia o local e o serviço de um registro anterior (a medição é do dia,
  // não se copia).
  Future<void> importar(Registro registro) async {
    // Via em branco vira null, que é o "sem via" do seletor e do filtro.
    final viaImportada = registro.via.trim().isEmpty ? null : registro.via;
    // Registro sem KM (obra que não usa) ou trecho que deixou de usar.
    final comKm = trechoTemKm(registro.trecho) && registro.km.trim().isNotEmpty;
    final listas = await Future.wait([
      comKm ? _catalogo.kms(registro.trecho) : Future.value(<String>[]),
      _catalogo.atividades(registro.trecho),
      _catalogo.servicos(registro.trecho, registro.atividade),
      _catalogo.passos(
          registro.trecho, registro.atividade, registro.servicoNotavel),
    ]);
    final estacas = await _estacasDoLocal(
        registro.trecho, comKm ? registro.km : null, viaImportada);

    trecho = registro.trecho;
    km = comKm ? registro.km : null;
    via = viaImportada;
    atividade = registro.atividade;
    estacaInicial = registro.estacaInicial;
    estacaFinal = registro.estacaFinal;
    estacasDoIntervalo = estacas;
    servico = registro.servicoNotavel;
    // Registro antigo pode vir sem passo: o campo fica em branco.
    passo = registro.servicoNotavelDetalhe.isEmpty
        ? null
        : registro.servicoNotavelDetalhe;
    quantidade.clear();
    unidade = null;
    descricao.text = registro.descricao;
    kms = listas[0];
    atividades = listas[1];
    servicos = listas[2];
    passos = listas[3];
    etapa = EtapaDoRegistro.local;
    notifyListeners();
  }

  // ── Conferência e navegação entre as etapas ───────────────────────────────

  // O que falta no local; null quando dá para seguir.
  String? erroDoLocal() {
    if (trecho == null) return 'Selecione o trecho em que está atuando';
    if (pedeKm && km == null) return 'Selecione o KM';
    if (pedeVia && via == null) return 'Selecione o sentido da via';
    if (pedeEstaca && (estacaInicial == null || estacaFinal == null)) {
      return 'Selecione a estaca inicial e a final';
    }
    return null;
  }

  // O que falta no serviço; null quando dá para tirar as fotos.
  String? erroDoServico() {
    if (atividade == null) return 'Selecione a atividade';
    if (servico == null) return 'Selecione o serviço';
    if (passo == null) return 'Selecione o passo do serviço';
    // Quantidade e unidade vêm juntas ou nenhuma.
    final valor = quantidadeInformada();
    if (quantidade.text.trim().isNotEmpty && valor == null) {
      return 'Quantidade inválida: use só números (ex.: 120,5)';
    }
    if (valor != null && unidade == null) {
      return 'Escolha a unidade da quantidade';
    }
    if (valor == null && unidade != null) {
      return 'Informe a quantidade da medição';
    }
    return null;
  }

  // Aceita vírgula ou ponto decimal; null se vazio ou inválido.
  double? quantidadeInformada() {
    final texto = quantidade.text.trim().replaceAll(',', '.');
    if (texto.isEmpty) return null;
    return double.tryParse(texto);
  }

  // Vai para o serviço; devolve o erro do local, se houver.
  String? avancar() {
    final erro = erroDoLocal();
    if (erro != null) return erro;
    etapa = EtapaDoRegistro.servico;
    notifyListeners();
    return null;
  }

  void voltar() {
    etapa = EtapaDoRegistro.local;
    notifyListeners();
  }

  // ── Gravação ──────────────────────────────────────────────────────────────

  // Grava o registro no aparelho e devolve o que a câmera carimba.
  // Chame só depois de [erroDoServico] voltar null.
  Future<RegistroParaFotos> gravar(int usuarioId) async {
    // O KM de cada ponta sai da estaca escolhida; sem KM, fica em branco.
    final kmInicio = pedeKm ? _lista.porRotulo(estacaInicial)?.km ?? km! : '';
    final kmFim = pedeKm ? _lista.porRotulo(estacaFinal)?.km ?? kmInicio : '';
    final viaGravada = pedeVia ? (via ?? '') : '';
    final inicial = pedeEstaca ? estacaInicial! : '';
    final finalDaFaixa = pedeEstaca ? estacaFinal! : '';

    final id = await _registros.criarRegistro(
      usuarioId: usuarioId,
      trecho: trecho!,
      km: kmInicio,
      // Só quando o serviço atravessa o KM.
      kmFinal: kmFim == kmInicio ? '' : kmFim,
      via: viaGravada,
      atividade: atividade!,
      estacaInicial: inicial,
      estacaFinal: finalDaFaixa,
      servicoNotavel: servico!,
      servicoNotavelDetalhe: passo!,
      quantidade: quantidadeInformada(),
      unidade: unidade ?? '',
      emNomeDeMatricula: registrandoPara?.matricula ?? '',
      emNomeDeNome: registrandoPara?.nome ?? '',
      descricao: descricao.text,
    );
    return (
      registroId: id,
      trecho: trecho!,
      // "231" ou "231 a 232".
      faixaDeKm: faixaDeKm(kmInicio, kmFim),
      estacaInicial: inicial,
      estacaFinal: finalDaFaixa,
      via: viaGravada,
      descricao: descricao.text,
      servico: servico!,
      passo: passo!,
    );
  }

  // Depois das fotos: a medição é deste registro só; o local fica para o
  // próximo, que costuma ser ali perto.
  void depoisDasFotos() {
    quantidade.clear();
    unidade = null;
    etapa = EtapaDoRegistro.local;
    notifyListeners();
  }

  // ── Ditado ────────────────────────────────────────────────────────────────

  // Liga ou desliga o ditado da descrição; devolve um erro para mostrar.
  Future<String?> alternarDitado() async {
    if (ditando) {
      await _ditado.parar();
      ditando = false;
      notifyListeners();
      return null;
    }
    if (!await _ditado.iniciar()) {
      return 'Reconhecimento de voz não disponível neste aparelho';
    }
    _textoAntesDoDitado = descricao.text;
    ditando = true;
    notifyListeners();
    await _ditado.ouvir(
      aoReconhecer: (texto) {
        final prefixo =
            _textoAntesDoDitado.isEmpty ? '' : '$_textoAntesDoDitado ';
        descricao.text = '$prefixo$texto';
        descricao.selection =
            TextSelection.collapsed(offset: descricao.text.length);
      },
      aoTerminar: () {
        ditando = false;
        notifyListeners();
      },
    );
    return null;
  }

  // Uma busca (CSV, GPS) pode terminar depois de a casca sair (logout); o
  // DescarteSeguro ignora o aviso que chegar depois do descarte.
  @override
  void dispose() {
    _ditado.cancelar();
    descricao.dispose();
    quantidade.dispose();
    super.dispose();
  }
}
