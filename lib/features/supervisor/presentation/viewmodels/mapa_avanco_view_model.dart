import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../../core/obra/dia_de_trabalho.dart';
import '../../../mapa/domain/entities/estaca_navegavel.dart';
import '../../domain/entities/registro_da_equipe.dart';
import '../../domain/regras/avanco.dart';

// Janela de tempo do mapa da equipe.
enum PeriodoDoMapa {
  hoje(1, 'Hoje'),
  semana(7, '7 dias'),
  mes(30, '30 dias'),
  trimestre(90, '90 dias'),
  tudo(null, 'Tudo');

  final int? dias;
  final String rotulo;
  const PeriodoDoMapa(this.dias, this.rotulo);
}

// Um registro desenhado: linha (várias estacas) ou ponto (uma só).
typedef TracoDoAvanco = ({
  RegistroDaEquipe registro,
  List<LatLng> pontos,
  int cor,
  bool recente,
});

// Onde cada serviço foi executado, sobre as estacas do projeto, com o
// acumulado por serviço e KM. Dois jeitos: o da equipe (supervisor, do
// servidor, por período) e o do encarregado (só o dele, dia a dia, do
// aparelho).
class MapaAvancoViewModel extends ChangeNotifier with DescarteSeguro {
  MapaAvancoViewModel({
    required Future<List<EstacaNavegavel>> Function() estacasDoProjeto,
    Future<List<RegistroDaEquipe>?> Function(DateTime? desde)? registrosDaEquipe,
    Future<List<RegistroDaEquipe>> Function(DateTime dia)? registrosDoDia,
    RelogioDoTurno relogio = const RelogioDoTurno(),
    DateTime? dia,
  })  : assert((registrosDaEquipe == null) != (registrosDoDia == null)),
        _estacasDoProjeto = estacasDoProjeto,
        _registrosDaEquipe = registrosDaEquipe,
        _registrosDoDia = registrosDoDia,
        _relogio = relogio {
    _dia = (dia ?? hoje).soDia;
  }

  final Future<List<EstacaNavegavel>> Function() _estacasDoProjeto;

  // Equipe: registros desde o início do período (null = tudo); null se falhar.
  final Future<List<RegistroDaEquipe>?> Function(DateTime? desde)?
      _registrosDaEquipe;

  // Encarregado: os registros dele no dia de trabalho, do aparelho.
  final Future<List<RegistroDaEquipe>> Function(DateTime dia)? _registrosDoDia;
  final RelogioDoTurno _relogio;

  PeriodoDoMapa _periodo = PeriodoDoMapa.mes;
  late DateTime _dia;
  String? _servico; // null = todos
  String? _encarregado; // matrícula; null = todos

  EstacasPorTrecho _estacas = {};
  List<List<LatLng>> _eixos = const [];
  List<RegistroDaEquipe> _registros = const [];
  bool _carregando = true;
  String? _erro;

  // Cada busca ganha um número; só a mais nova mexe na tela.
  int _busca = 0;

  // Estacas cobertas por registro: valem enquanto os registros e as estacas
  // forem os mesmos (refazer custa uma varredura do trecho por registro).
  final _cobertas = Map<RegistroDaEquipe, List<EstacaNavegavel>>.identity();

  // O resto das contas fica guardado até algo mudar: antes eram refeitas a
  // cada desenho.
  List<RegistroDaEquipe>? _doEncarregadoGuardados;
  List<RegistroDaEquipe>? _filtradosGuardados;
  List<String>? _servicosGuardados;
  Map<String, int>? _coresGuardadas;
  List<AvancoDoServico>? _resumoGuardado;
  List<TracoDoAvanco>? _tracosGuardados;
  List<LatLng>? _pontosGuardados;
  List<({String matricula, String nome})>? _encarregadosGuardados;

  void _esquecerContas() {
    _doEncarregadoGuardados = null;
    _filtradosGuardados = null;
    _servicosGuardados = null;
    _coresGuardadas = null;
    _resumoGuardado = null;
    _tracosGuardados = null;
    _pontosGuardados = null;
    _encarregadosGuardados = null;
  }

  // Esquece as contas antes da mudança (o que ela ler já sai do estado novo)
  // e depois (o que foi lido com a mudança pela metade não fica guardado).
  void _atualizar(VoidCallback mudanca) => mudar(() {
        _esquecerContas();
        mudanca();
        _esquecerContas();
      });

  List<EstacaNavegavel> _cobertasDe(RegistroDaEquipe r) =>
      _cobertas.putIfAbsent(r, () => estacasDoRegistro(r, _estacas));

  bool get doEncarregado => _registrosDoDia != null;
  String get titulo => doEncarregado ? 'Mapa do dia' : 'Mapa de avanço';
  PeriodoDoMapa get periodo => _periodo;
  DateTime get dia => _dia;
  DateTime get hoje => _relogio.hoje;
  String? get servico => _servico;
  String? get encarregado => _encarregado;
  bool get carregando => _carregando;
  String? get erro => _erro;
  List<List<LatLng>> get eixos => _eixos;
  bool get semNadaAinda => _carregando && _registros.isEmpty;

  // Quem aparece no período, por nome.
  List<({String matricula, String nome})> get encarregados =>
      _encarregadosGuardados ??= () {
        final nomes = <String, String>{
          for (final r in _registros) r.usuarioMatricula: r.usuarioNome,
        };
        return [
          for (final e in nomes.entries) (matricula: e.key, nome: e.value),
        ]..sort((a, b) => a.nome.compareTo(b.nome));
      }();

  List<RegistroDaEquipe> get _doEncarregado =>
      _doEncarregadoGuardados ??= _encarregado == null
          ? _registros
          : [
              for (final r in _registros)
                if (r.usuarioMatricula == _encarregado) r,
            ];

  List<RegistroDaEquipe> get filtrados => _filtradosGuardados ??= _servico == null
      ? _doEncarregado
      : [
          for (final r in _doEncarregado)
            if (r.servicoNotavel == _servico) r,
        ];

  // Do mais ao menos registrado; a posição dá a cor (a mesma do relatório).
  List<String> get servicos => _servicosGuardados ??=
      servicosPorFrequencia(_doEncarregado.map((r) => r.servicoNotavel));

  int corDe(String servico) => (_coresGuardadas ??= {
        for (final s in servicos) s: corDoServico(s, servicos),
      })[servico] ??
      corDoServico(servico, servicos);

  List<AvancoDoServico> get resumo => _resumoGuardado ??=
      resumirAvanco(filtrados, _estacas, cobertasDe: _cobertasDe);

  // Do mais antigo ao mais novo: o recente fica por cima no mapa.
  List<TracoDoAvanco> get tracos => _tracosGuardados ??= () {
        final agora = _relogio.agora();
        return [
          for (final r in filtrados)
            if (_cobertasDe(r) case final estacas when estacas.isNotEmpty)
              (
                registro: r,
                pontos: [for (final e in estacas) e.ponto],
                cor: corDe(r.servicoNotavel),
                recente: registroRecente(r, agora),
              ),
        ];
      }();

  // Pontos do que está filtrado, para enquadrar o mapa.
  List<LatLng> get pontosFiltrados =>
      _pontosGuardados ??= [for (final t in tracos) ...t.pontos];

  String get tituloDoResumo => filtrados.isEmpty
      ? doEncarregado
          ? 'Nenhum registro neste dia'
          : 'Nenhum registro no período'
      : '${filtrados.length} registro(s) · ${resumo.length} serviço(s)';

  String get dicaDoResumo {
    final foraDoMapa = resumo.fold(0, (soma, s) => soma + s.foraDoMapa);
    return '${doEncarregado ? '' : 'Linha forte: últimos 7 dias. '}'
        'Toque numa linha para ver o registro.'
        '${foraDoMapa > 0 ? '\n$foraDoMapa registro(s) sem estaca no mapa '
            '(área de apoio ou estaca sem coordenada).' : ''}';
  }

  // "1850 m³ · 320 m · 4 registro(s)"
  String numeros(Map<String, double> quantidades, double metros, int registros) => [
        if (quantidades.isNotEmpty) formatarQuantidades(quantidades),
        if (metros > 0) formatarExtensao(metros),
        '$registros registro(s)',
      ].join(' · ');

  String tituloDoKm(AvancoDoKm km) =>
      km.km.isEmpty ? km.trecho : '${km.trecho} · KM ${km.km}';

  String tituloDoDetalhe(RegistroDaEquipe r) => r.servicoNotavelDetalhe.isEmpty
      ? r.servicoNotavel
      : '${r.servicoNotavel} (${r.servicoNotavelDetalhe})';

  // "C1 / KM 225 · Est. EST. 1115 a EST. 1117 · Via 02 Norte"
  // "Ana Lima · 24/09/2026 às 08:10 · 120 m³"
  String subtituloDoDetalhe(RegistroDaEquipe r) => [
        [
          r.local,
          if (r.estacas.isNotEmpty) 'Est. ${r.estacas}',
          if (r.via.isNotEmpty) r.via,
        ].join(' · '),
        [
          r.usuarioNome,
          '${r.criadoEm.dataCurta} às ${r.criadoEm.horaCurta}',
          if (r.medicao.isNotEmpty) r.medicao,
        ].join(' · '),
      ].join('\n');

  DateTime? get _inicioDoPeriodo {
    final dias = _periodo.dias;
    if (dias == null) return null;
    final hoje = _relogio.agora();
    return DateTime(hoje.year, hoje.month, hoje.day - dias + 1);
  }

  // Erro na busca não deixa a tela girando: mostra o aviso com o "Tentar de
  // novo".
  Future<void> carregar() async {
    final busca = ++_busca;
    _atualizar(() {
      _carregando = true;
      _erro = null;
    });
    try {
      if (_estacas.isEmpty) {
        final estacas = agruparEstacasPorTrecho(await _estacasDoProjeto());
        _estacas = estacas;
        _eixos = eixosPorPista(estacas);
        _cobertas.clear();
      }
      final registros = doEncarregado
          ? await _registrosDoDia!(_dia)
          : await _registrosDaEquipe!(_inicioDoPeriodo);
      // Outra busca começou depois desta: ela é que termina o carregamento.
      if (busca != _busca) return;
      _atualizar(() {
        _carregando = false;
        if (registros == null) {
          _erro = 'Não foi possível buscar os registros. Confira a internet.';
          return;
        }
        _registros = registros;
        _cobertas.clear();
        // Filtro que sumiu do período volta para "todos".
        if (_servico != null && !registros.any((r) => r.servicoNotavel == _servico)) {
          _servico = null;
        }
        if (_encarregado != null &&
            !registros.any((r) => r.usuarioMatricula == _encarregado)) {
          _encarregado = null;
        }
      });
    } catch (e) {
      debugPrint('Mapa de avanço: a busca falhou: $e');
      if (busca != _busca) return;
      _atualizar(() {
        _carregando = false;
        _erro = 'Não foi possível carregar o mapa. Tente de novo.';
      });
    }
  }

  Future<void> escolherPeriodo(PeriodoDoMapa periodo) async {
    if (periodo == _periodo) return;
    _periodo = periodo;
    await carregar();
  }

  Future<void> mudarDia(DateTime dia) async {
    _dia = dia.soDia;
    await carregar();
  }

  void escolherServico(String? servico) => _atualizar(() => _servico = servico);

  void escolherEncarregado(String? matricula) => _atualizar(() {
        _encarregado = matricula;
        // O serviço escolhido pode não existir para ele.
        if (_servico != null &&
            !_doEncarregado.any((r) => r.servicoNotavel == _servico)) {
          _servico = null;
        }
      });
}
