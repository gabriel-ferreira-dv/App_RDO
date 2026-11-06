import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../../core/obra/dia_de_trabalho.dart';
import '../../domain/entities/foto_da_paralisacao.dart';
import '../../domain/entities/paralisacao.dart';
import '../../domain/repositories/paralisacao_repository.dart';
import '../../domain/usecases/salvar_paralisacao.dart';

// Formulário de uma paralisação: nova no dia de trabalho [dia], ou edição de
// uma existente. Toda a regra fica aqui; a tela só desenha e repassa toques.
class ParalisacaoFormViewModel extends ChangeNotifier with DescarteSeguro {
  ParalisacaoFormViewModel({
    required SalvarParalisacao salvarParalisacao,
    required ParalisacaoRepository repositorio,
    required Future<List<String>> Function() carregarTrechos,
    required Future<List<String>> Function(String trecho) carregarKms,
    required this.usuarioId,
    required DateTime dia,
    this.noturno = false,
    Paralisacao? existente,
    DateTime Function() agora = DateTime.now,
  })  : _salvarParalisacao = salvarParalisacao,
        _repositorio = repositorio,
        _carregarTrechos = carregarTrechos,
        _carregarKms = carregarKms,
        _agora = agora,
        dia = dia.soDia,
        _existente = existente,
        _id = existente?.id,
        _criadoEm = existente?.criadoEm ?? agora().toUtc().toIso8601String() {
    final p = existente;
    if (p != null) {
      _motivo = p.motivo;
      _inicio = p.inicio.toLocal();
      _fim = p.fim?.toLocal();
      _trecho = p.trecho.isEmpty ? null : p.trecho;
      _km = p.km.isEmpty ? null : p.km;
      _observacao = p.observacao;
    } else if (ehHoje) {
      // Parou agora: começa agora e segue sem término.
      _inicio = agora();
    } else {
      // Lançamento de outro dia: um horário qualquer para ajustar.
      _inicio = DateTime(this.dia.year, this.dia.month, this.dia.day, 13);
      _fim = _inicio.add(const Duration(hours: 1));
    }
  }

  final SalvarParalisacao _salvarParalisacao;
  final ParalisacaoRepository _repositorio;
  final Future<List<String>> Function() _carregarTrechos;
  final Future<List<String>> Function(String trecho) _carregarKms;
  final DateTime Function() _agora;
  final Paralisacao? _existente;

  final int usuarioId;
  final DateTime dia;
  final bool noturno;

  int? _id;
  final String _criadoEm;
  String? _motivo;
  late DateTime _inicio; // local
  DateTime? _fim; // local; null = ainda parado
  String? _trecho;
  String? _km;
  String _observacao = '';
  List<String> _trechos = [];
  List<String> _kms = [];
  List<FotoDaParalisacao> _fotos = [];
  bool _salvando = false;

  // ── Estado para a tela ────────────────────────────────────────────────────

  bool get ehHoje => dia == diaDoTurno(_agora(), noturno: noturno);
  bool get jaGravada => _id != null;
  String get titulo => jaGravada ? 'Paralisação' : 'Registrar paralisação';

  String? get motivo => _motivo;
  DateTime get inicio => _inicio;
  DateTime? get fim => _fim;
  bool get aindaParado => _fim == null;
  String get observacao => _observacao;
  bool get salvando => _salvando;

  String get rotuloInicio => 'Parou: ${_inicio.horaCurta}';
  String get rotuloFim => 'Voltou: ${_fim?.horaCurta ?? '--:--'}';

  // Voltou depois da meia-noite: "Voltou no dia 25/09".
  String? get avisoDeOutroDia {
    final fim = _fim;
    return fim != null && fim.soDia != _inicio.soDia
        ? 'Voltou no dia ${fim.diaEMes}'
        : null;
  }

  String? get trecho => _trecho;
  String? get km => _km;

  // A opção escolhida sempre aparece, mesmo fora da lista do projeto.
  List<String> get trechos =>
      {..._trechos, if (_trecho != null) _trecho!}.toList();
  List<String> get kms => {..._kms, if (_km != null) _km!}.toList();

  List<String> get caminhosDasFotos =>
      [for (final f in _fotos) f.caminhoArquivo];
  String get rotuloDaFoto =>
      _fotos.isEmpty ? 'Salvar e tirar foto' : 'Salvar e tirar mais fotos';

  // Textos do carimbo da foto.
  String get servicoNoCarimbo => 'PARALISAÇÃO - ${_motivo ?? ''}';
  String get detalheNoCarimbo => _fim == null
      ? 'Parado desde ${_inicio.horaCurta}'
      : 'Parado das ${_inicio.horaCurta} às ${_fim!.horaCurta}';

  // ── Ações ─────────────────────────────────────────────────────────────────

  // Carrega listas, fotos e a sugestão de local (chamar ao abrir a tela).
  // Tudo ao mesmo tempo: as fotos e a sugestão não esperam a planilha dos
  // trechos.
  Future<void> iniciar() async {
    await Future.wait([
      _carregarListaDeTrechos(),
      if (_trecho != null) _atualizarKms(_trecho!),
      if (_existente != null)
        recarregarFotos()
      else if (ehHoje)
        _sugerirLocal(),
    ]);
  }

  void escolherMotivo(String motivo) => mudar(() => _motivo = motivo);

  void definirInicio(int hora, int minuto) =>
      mudar(() => _inicio = _noDia(hora, minuto));

  void definirFim(int hora, int minuto) {
    var fim = DateTime(_inicio.year, _inicio.month, _inicio.day, hora, minuto);
    // Antes do início: passou da meia-noite.
    if (!fim.isAfter(_inicio)) fim = fim.add(const Duration(days: 1));
    mudar(() => _fim = fim);
  }

  void definirAindaParado(bool parado) =>
      mudar(() => _fim = parado ? null : _terminoSugerido());

  Future<void> escolherTrecho(String? trecho) async {
    mudar(() {
      _trecho = trecho;
      _km = null;
      _kms = [];
    });
    if (trecho != null) await _atualizarKms(trecho);
  }

  void escolherKm(String? km) => mudar(() => _km = km);

  // Sem avisar a tela: o campo de texto já mostra o que foi digitado.
  void definirObservacao(String texto) => _observacao = texto;

  Future<ResultadoAoSalvar> salvar() async {
    mudar(() => _salvando = true);
    try {
      final resultado = await _salvarParalisacao(
        id: _id,
        usuarioId: usuarioId,
        motivo: _motivo,
        inicio: _inicio,
        fim: _fim,
        observacao: _observacao,
        trecho: _trecho ?? '',
        km: _km ?? '',
        criadoEm: _criadoEm,
      );
      if (resultado case Salvou(:final id)) _id = id;
      return resultado;
    } finally {
      mudar(() => _salvando = false);
    }
  }

  Future<void> excluir() async {
    final id = _id;
    if (id != null) await _repositorio.excluir(id);
  }

  // Foto tirada na câmera (a paralisação já foi salva antes).
  Future<void> registrarFoto(String caminho,
      {double? latitude, double? longitude}) async {
    final id = _id;
    if (id == null) return;
    await _repositorio.adicionarFoto(
      paralisacaoId: id,
      caminhoArquivo: caminho,
      latitude: latitude,
      longitude: longitude,
      quando: _agora(),
    );
  }

  Future<void> recarregarFotos() async {
    final id = _id;
    if (id == null) return;
    final fotos = await _repositorio.fotosDe(id);
    mudar(() => _fotos = fotos);
  }

  // ── Por dentro ────────────────────────────────────────────────────────────

  Future<void> _carregarListaDeTrechos() async {
    final trechos = await _carregarTrechos();
    mudar(() => _trechos = trechos);
  }

  // Trecho e KM do último registro de hoje, se ainda não escolheu.
  Future<void> _sugerirLocal() async {
    final local =
        await _repositorio.ultimoLocalDesde(usuarioId, _agora().soDia);
    if (local == null || _trecho != null) return;
    mudar(() {
      _trecho = local.trecho.isEmpty ? null : local.trecho;
      _km = local.km.isEmpty ? null : local.km;
    });
    if (_trecho != null) await _atualizarKms(_trecho!);
  }

  Future<void> _atualizarKms(String trecho) async {
    final kms = await _carregarKms(trecho);
    // O trecho pode ter mudado enquanto carregava.
    if (trecho == _trecho) mudar(() => _kms = kms);
  }

  // Hora escolhida levada para o dia de trabalho: no turno da noite, a
  // madrugada é do dia seguinte.
  DateTime _noDia(int hora, int minuto) {
    final madrugada = noturno && hora < horaViradaTurnoNoturno;
    return DateTime(
        dia.year, dia.month, dia.day + (madrugada ? 1 : 0), hora, minuto);
  }

  // Término sugerido ao desligar "Ainda parado".
  DateTime _terminoSugerido() {
    final agora = _agora();
    return agora.isAfter(_inicio) && agora.difference(_inicio).inHours < 24
        ? agora
        : _inicio.add(const Duration(hours: 1));
  }
}
