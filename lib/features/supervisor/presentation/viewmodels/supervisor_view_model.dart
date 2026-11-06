import 'package:flutter/foundation.dart';

import '../../../../core/estado/descarte_seguro.dart';
import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../../core/obra/dia_de_trabalho.dart';
import '../../../paralisacao/domain/entities/paralisacao.dart' show formatarDuracao;
import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../domain/entities/encarregado_da_equipe.dart';
import '../../domain/entities/foto_consolidada.dart';
import '../../domain/entities/registro_da_equipe.dart';
import '../../domain/entities/resumo_do_encarregado.dart';
import '../../domain/regras/atividades_do_dia.dart';
import '../../domain/repositories/equipe_repository.dart';
import '../../domain/repositories/registros_da_equipe_repository.dart';
import '../../domain/usecases/baixar_fotos_do_consolidado.dart';
import '../../domain/usecases/carregar_dia_da_equipe.dart';

// Monta o PDF do dia da equipe (ver gerarPdfDaEquipe).
typedef GerarPdfDaEquipe = Future<Uint8List> Function({
  required List<ResumoDoEncarregado> resumos,
  required List<List<FotoConsolidada>> fotos,
  required String supervisor,
  required DateTime dia,
});

// O PDF pronto, com o título e o nome do arquivo do dia em que foi gerado.
typedef RelatorioDaEquipe = ({Uint8List bytes, String titulo, String arquivo});

// O dia de um encarregado pronto para o cartão. Os textos são montados uma
// vez por busca, não a cada desenho da tela.
class CartaoDoDia {
  final ResumoDoEncarregado resumo;
  final List<String> atividades;

  // "11 no efetivo · 3 atividade(s) · 1h20 parado"
  final String subtitulo;

  // Cada registro com a linha dele ("08:10 · C1 / KM 225 · ...").
  final List<({RegistroDaEquipe registro, String linha})> registros;

  // "Último registro às 14:20"; null sem registro.
  final String? ultimoRegistro;

  CartaoDoDia._(this.resumo, this.atividades, this.subtitulo, this.registros,
      this.ultimoRegistro);

  factory CartaoDoDia.de(ResumoDoEncarregado r) {
    final atividades = listarAtividades(r.registros);
    return CartaoDoDia._(
      r,
      atividades,
      [
        '${r.totalPessoas} no efetivo',
        '${atividades.length} atividade(s)',
        if (r.aindaParado)
          'PARADO AGORA'
        else if (r.paralisacoes.isNotEmpty)
          '${formatarDuracao(r.totalParado)} parado',
      ].join(' · '),
      [
        for (final registro in r.registros)
          (
            registro: registro,
            linha: '${registro.criadoEm.horaCurta} · ${registro.local} · '
                '${registro.atividade} — ${registro.servicoNotavel}',
          ),
      ],
      r.registros.isEmpty
          ? null
          : 'Último registro às ${r.registros.last.criadoEm.horaCurta}',
    );
  }
}

// Aba Equipe: o dia de cada encarregado, a correção dos registros e o
// relatório consolidado.
class SupervisorViewModel extends ChangeNotifier with DescarteSeguro {
  SupervisorViewModel({
    required EquipeRepository equipe,
    required RegistrosDaEquipeRepository registros,
    required CarregarDiaDaEquipe carregarDia,
    required BaixarFotosDoConsolidado baixarFotos,
    required GerarPdfDaEquipe gerarPdf,
    required String Function() matricula,
    required this.supervisorNome,
    RelogioDoTurno relogio = const RelogioDoTurno(),
    Future<void> Function()? prepararSessao,
  })  : _equipe = equipe,
        _registros = registros,
        _carregarDia = carregarDia,
        _baixarFotos = baixarFotos,
        _gerarPdf = gerarPdf,
        _matricula = matricula,
        _relogio = relogio,
        _prepararSessao = prepararSessao;

  final EquipeRepository _equipe;
  final RegistrosDaEquipeRepository _registros;
  final CarregarDiaDaEquipe _carregarDia;
  final BaixarFotosDoConsolidado _baixarFotos;
  final GerarPdfDaEquipe _gerarPdf;

  // Lida a cada uso: o perfil é renovado ao carregar.
  final String Function() _matricula;
  final RelogioDoTurno _relogio;

  // Renova o token (o banco lê a matrícula de dentro dele) e a lista do turno
  // da noite, antes de buscar.
  final Future<void> Function()? _prepararSessao;

  final String supervisorNome;

  DateTime? _diaEscolhido; // null = hoje
  DateTime? _diaCarregado; // o dia dos cartões na tela
  List<EncarregadoDaEquipe> _equipeDoSupervisor = const [];
  List<ResumoDoEncarregado> _resumos = const [];
  List<CartaoDoDia> _cartoes = const [];
  bool _carregando = true;
  bool _incluirFotos = false;
  bool _gerando = false;
  int _fotosBaixadas = 0;
  int _fotosTotal = 0;

  // Cada busca ganha um número; só a mais nova mexe na tela.
  int _busca = 0;

  String get matricula => _matricula().trim();
  DateTime get hoje => _relogio.hoje;
  DateTime get _diaPedido => _diaEscolhido ?? hoje;

  // O dia que a tela mostra é o dos cartões. Se a meia-noite (ou a virada do
  // turno) passa com a tela aberta, o rótulo continua o do que está nela.
  DateTime get dia => _diaCarregado ?? _diaPedido;

  List<EncarregadoDaEquipe> get equipe => _equipeDoSupervisor;
  List<CartaoDoDia> get cartoes => _cartoes;
  bool get carregando => _carregando;
  bool get temEquipe => _equipeDoSupervisor.isNotEmpty;
  bool get incluirFotos => _incluirFotos;
  bool get gerando => _gerando;

  // A equipe no mapa de avanço, e o que o próprio supervisor registrou.
  List<String> get matriculasDoMapa => [
        for (final e in _equipeDoSupervisor) e.matricula,
        if (matricula.isNotEmpty) matricula,
      ];

  String get rotuloDoRelatorio => !_gerando
      ? 'Gerar relatório da equipe'
      : _fotosBaixadas < _fotosTotal
          ? 'Baixando fotos $_fotosBaixadas de $_fotosTotal…'
          : 'Gerando…';

  String subtituloDaCorrecao(RegistroDaEquipe r) =>
      'De ${r.usuarioNome}, ${r.criadoEm.horaCurta}';

  Future<void> carregar() async {
    final busca = ++_busca;
    mudar(() => _carregando = true);
    try {
      try {
        await _prepararSessao?.call();
      } catch (e) {
        debugPrint('Renovar a sessão do supervisor falhou: $e');
      }
      // O dia só é decidido depois de renovar a sessão: a lista do turno da
      // noite que chega agora pode mudar o "hoje".
      final pedido = _diaPedido;
      final equipe = await _equipe.equipeDe(matricula);
      final resumos = await _carregarDia(equipe, pedido);
      // Outra busca começou depois desta: ela é que termina o carregamento.
      if (busca != _busca) return;
      mudar(() {
        _equipeDoSupervisor = equipe;
        _resumos = resumos;
        _cartoes = [for (final r in resumos) CartaoDoDia.de(r)];
        _diaCarregado = pedido;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Busca do dia da equipe falhou: $e');
      if (busca == _busca) mudar(() => _carregando = false);
    }
  }

  void mudarDia(DateTime novo) {
    final escolhido = novo.soDia.isBefore(hoje) ? novo.soDia : null;
    if (escolhido == _diaEscolhido && _diaPedido == _diaCarregado) return;
    _diaEscolhido = escolhido;
    carregar();
  }

  void definirIncluirFotos(bool valor) => mudar(() => _incluirFotos = valor);

  // O PDF do que está na tela; null se falhar. Trocar de dia no meio não
  // muda o relatório: ele sai do dia em que foi pedido.
  Future<RelatorioDaEquipe?> gerarRelatorio() async {
    final resumos = _resumos;
    final dia = this.dia;
    mudar(() {
      _gerando = true;
      _fotosBaixadas = 0;
      _fotosTotal = 0;
    });
    try {
      final fotos = _incluirFotos
          ? await _baixarFotos(resumos,
              aoProgredir: (baixadas, total) => mudar(() {
                    _fotosBaixadas = baixadas;
                    _fotosTotal = total;
                  }))
          : [for (final _ in resumos) const <FotoConsolidada>[]];
      final bytes = await _gerarPdf(
          resumos: resumos, fotos: fotos, supervisor: supervisorNome, dia: dia);
      return (
        bytes: bytes,
        titulo: 'Equipe — ${dia.dataCurta}',
        arquivo: 'equipe_${dia.dataCompacta}.pdf',
      );
    } catch (e) {
      debugPrint('Relatório da equipe falhou: $e');
      return null;
    } finally {
      mudar(() => _gerando = false);
    }
  }

  // Grava no servidor; devolve a mensagem para o usuário.
  Future<String> corrigir(RegistroDaEquipe registro, CamposDoRegistro campos) async {
    final erro = await _registros.corrigir(registro, campos);
    if (erro != null) return erro;
    carregar();
    return 'Registro corrigido. As fotos ganham o carimbo novo quando o '
        'celular de quem as tirou sincronizar.';
  }
}
