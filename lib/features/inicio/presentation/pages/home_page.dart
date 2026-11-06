import 'dart:async';

import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../../../app/rotas.dart';
import '../../../../core/widgets/botao_do_tema.dart';
import '../../../admin/presentation/pages/registros_dos_usuarios_page.dart';
import '../../../auth/auth_service.dart';
import '../../../auth/models/usuario.dart';
import '../../../camera/data/datasources/carimbo_service.dart';
import '../../../historico/presentation/pages/historico_page.dart';
import '../../../mapa/domain/regras/mapas_da_obra.dart';
import '../../../mapa/data/datasources/permissao_mapas_service.dart';
import '../../../mapa/data/datasources/mapas_do_projeto.dart' show locAtual;
import '../../../mapa/presentation/pages/map_page.dart';
import '../../../mapa/presentation/widgets/mini_mapa.dart';
import '../../../notificacoes/lembretes_service.dart';
import '../../../notificacoes/mensagens_service.dart';
import '../../../notificacoes/presentation/pages/atualizacoes_page.dart';
import '../../../paralisacao/presentation/pages/paralisacoes_page.dart';
import '../../../registro/presentation/viewmodels/formulario_de_registro.dart';
import '../../../registro/presentation/pages/registro_page.dart';
import '../../../registro/presentation/widgets/progresso_das_etapas.dart';
import '../../../relatorio/presentation/pages/relatorio_page.dart';
import '../../../relatorio/turno_noturno.dart';
import '../../../sincronizacao/presentation/widgets/atualizacao_app_dialogo.dart';
import '../../../supervisor/domain/entities/encarregado_da_equipe.dart';
import '../../../supervisor/presentation/pages/supervisor_page.dart';
import '../../../tutorial/presentation/pages/tutorial_page.dart';
import '../../inicio_service.dart';
import '../widgets/barra_de_navegacao.dart';
import '../widgets/menu_da_conta.dart';
import '../widgets/menu_mais.dart';
import '../widgets/saudacao_do_inicio.dart';
import 'inicio_page.dart';

enum _Aba {
  inicio,
  historico,
  registro,
  mapa,
  paradas,
  relatorio,
  equipe,
  registrosDosUsuarios,
  comoUsar
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Usuario usuario;
  final VoidCallback aoSair;

  const HomePage({
    super.key,
    required this.cameras,
    required this.usuario,
    required this.aoSair,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _aba = _Aba.inicio;

  late bool _ehSupervisor = widget.usuario.ehSupervisor;
  bool _ehAdmin = false;
  bool _paradoAgora = false;
  final _formulario = Dependencias.formularioDeRegistro();

  StreamSubscription<List<ConnectivityResult>>? _conectividade;

  @override
  void initState() {
    super.initState();
    _formulario.carregarTrechos();
    aquecerProcessadorFoto();
    Dependencias.sincronizacao.sincronizar();
    _conectividade = Connectivity().onConnectivityChanged.listen((resultados) {
      final online = resultados.any((r) => r != ConnectivityResult.none);
      if (online) Dependencias.sincronizacao.sincronizar();
    });
    //Config da obra que fica no supabase, para pegar o aviso de privacidade da filial e a versão do app e maps e configuração de trechos e serviços
    final obra = Dependencias.configDaObra.sincronizar();
    Future.wait([
      obra,
      PermissaoMapasService.instancia.sincronizar(),
    ]).then((_) => _verificarAtualizacoesDeDados());
    TurnoNoturnoService.instancia.sincronizar();
    // Lembrete diário.
    LembretesService.instancia.agendarLembretesDiarios(widget.usuario.nome);
    // O aviso de privacidade da filial pode ter mudado no Supabase: pede ciência do aviso antes de verificar atualização do app.
    obra.then((_) => _pedirCienciaDoAviso()).then((_) {
      if (!mounted) return;
      _verificarAtualizacaoDoApp();
      _mostrarMensagensDoGestor();
    });
    _revalidarPerfil();
    _verificarAdmin();
    _atualizarParadoAgora();
  }

  @override
  void dispose() {
    _conectividade?.cancel();
    _formulario.dispose();
    super.dispose();
  }

  void _irPara(_Aba aba) {
    setState(() => _aba = aba);
    _atualizarParadoAgora();
  }

  ItemDaBarra? get _itemDaBarra => switch (_aba) {
        _Aba.inicio => ItemDaBarra.inicio,
        _Aba.historico => ItemDaBarra.historico,
        _Aba.mapa => ItemDaBarra.mapa,
        _Aba.registro => null,
        _ => ItemDaBarra.mais,
      };

  Future<void> _escolherNaBarra(ItemDaBarra item) async {
    switch (item) {
      case ItemDaBarra.inicio:
        _irPara(_Aba.inicio);
      case ItemDaBarra.historico:
        _irPara(_Aba.historico);
      case ItemDaBarra.mapa:
        _irPara(_Aba.mapa);
      case ItemDaBarra.mais:
        final opcao = await mostrarMenuMais(
          context,
          paradoAgora: _paradoAgora,
          ehSupervisor: _ehSupervisor,
          ehAdmin: _ehAdmin,
        );
        if (opcao != null) _abrirDoMais(opcao);
    }
  }

  void _abrirDoMais(OpcaoDoMais opcao) {
    switch (opcao) {
      case OpcaoDoMais.paradas:
        _irPara(_Aba.paradas);
      case OpcaoDoMais.relatorio:
        _irPara(_Aba.relatorio);
      case OpcaoDoMais.equipe:
        _irPara(_Aba.equipe);
      case OpcaoDoMais.registrosDosUsuarios:
        _irPara(_Aba.registrosDosUsuarios);
      case OpcaoDoMais.comoUsar:
        _irPara(_Aba.comoUsar);
      case OpcaoDoMais.atualizacoes:
        _abrirAtualizacoes();
      case OpcaoDoMais.privacidade:
        Rotas.avisoDePrivacidade(context, email: widget.usuario.email);
    }
  }

  void _abrirAtualizacoes() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AtualizacoesPage()),
      );

  void _aoVoltar() {
    if (_aba == _Aba.registro && _formulario.etapa == EtapaDoRegistro.servico) {
      _formulario.voltar();
    } else {
      _irPara(_Aba.inicio);
    }
  }

  Future<void> _atualizarParadoAgora() async {
    final parado = await Dependencias.estaParadoAgora(
      widget.usuario.id!,
      noturno: Dependencias.ehNoturno(widget.usuario),
    );
    if (mounted && parado != _paradoAgora) {
      setState(() => _paradoAgora = parado);
    }
  }

  Future<void> _revalidarPerfil() async {
    final usuario = await AuthService.instancia.sincronizarPerfil();
    if (!mounted || usuario == null) return;

    // Sessão expirada no servidor: o perfil fica congelado até novo login,
    // então avisa (senão uma promoção a supervisor nunca apareceria).
    if (AuthService.instancia.sessaoPrecisaRenovar) {
      _avisarSessaoExpirada();
      return;
    }

    if (usuario.ehSupervisor != _ehSupervisor) {
      setState(() {
        _ehSupervisor = usuario.ehSupervisor;
        // Perfil revogado com a Equipe aberta: volta para o Início.
        if (!_ehSupervisor && _aba == _Aba.equipe) _aba = _Aba.inicio;
      });
    }
    final equipe = usuario.ehSupervisor
        ? await Dependencias.equipe.equipeDe(usuario.matricula)
        : <EncarregadoDaEquipe>[];
    if (!mounted) return;
    _formulario.definirEquipe(equipe, ehSupervisor: usuario.ehSupervisor);
  }

  Future<void> _verificarAdmin() async {
    final admin = await Dependencias.admin.souAdmin();
    if (!mounted || admin == _ehAdmin) return;
    setState(() {
      _ehAdmin = admin;
      // Deixou de ser admin com a tela aberta: volta para o Início.
      if (!admin && _aba == _Aba.registrosDosUsuarios) _aba = _Aba.inicio;
    });
  }

  // Primeira abertura deste usuário, ou versão nova do aviso de privacidade
  // da filial no Supabase: mostra o aviso e espera o "Li e entendi" (LGPD,
  // art. 9º).
  Future<void> _pedirCienciaDoAviso() async {
    final email = widget.usuario.email;
    // Sem aviso pendente (já leu, ou sem internet e nunca baixado): segue.
    final aviso = await Dependencias.buscarAvisoPendente(
        email: email, filial: Dependencias.filial.codigo);
    if (aviso == null) return;
    // No initState o Navigator ainda está montando a casca.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Rotas.avisoDePrivacidade(context, email: email, avisoPendente: aviso);
  }

  // Barra fixa, e não SnackBar: o problema só passa com novo login.
  void _avisarSessaoExpirada() {
    // Depois do primeiro quadro: no initState o Scaffold ainda não existe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: const Text(
            'Sua sessão expirou. Entre novamente para atualizar seu perfil — '
            'sem isso, mudanças feitas pelo administrador não chegam neste '
            'aparelho.',
          ),
          leading: const Icon(Icons.gpp_maybe_outlined),
          actions: [
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('Agora não'),
            ),
            FilledButton(
              // Mesmo caminho do "Sair" do menu (o main cuida do logout).
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                widget.aoSair();
              },
              child: const Text('Entrar de novo'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _mostrarMensagensDoGestor() async {
    final mensagens =
        await MensagensService.instancia.buscarNovas(widget.usuario.email);
    for (final mensagem in mensagens) {
      LembretesService.instancia
          .exibirMensagemDoGestor(mensagem.id, mensagem.titulo, mensagem.corpo);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.campaign),
          title: Text(mensagem.titulo),
          content: Text(mensagem.corpo),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _verificarAtualizacoesDeDados() async {
    final resultado =
        await Dependencias.atualizacaoDados.verificarEAtualizarCsvs();
    if (!mounted) return;

    if (resultado.csvsAtualizados.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Dados do projeto atualizados: ${resultado.csvsAtualizados.join(', ')}',
        ),
      ));
    }
    if (resultado.overlaysNovos.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        // "Para baixar": o primeiro download de cada mapa também vem por aqui.
        content: Text(
          '${resultado.overlaysNovos.map(rotuloDoMapa).join(' e ')} para '
          'baixar — abra a tela de Atualizações, de preferência no Wi-Fi',
        ),
        action: SnackBarAction(label: 'Abrir', onPressed: _abrirAtualizacoes),
      ));
    }
  }

  // Versão nova do app no Supabase (ver supabase/versao_app.sql).
  Future<void> _verificarAtualizacaoDoApp() async {
    final atualizacao = await Dependencias.atualizacaoApp.verificar();
    if (atualizacao == null || !mounted) return;
    await oferecerAtualizacaoDoApp(context, atualizacao);
  }

  // ── Tela ──────────────────────────────────────────────────────────────────

  Widget? _telaDaAba() => switch (_aba) {
        _Aba.inicio => InicioPage(
            usuario: widget.usuario,
            ehSupervisor: _ehSupervisor,
            ehAdmin: _ehAdmin,
            aoNovoRegistro: () => _irPara(_Aba.registro),
            aoVerHistorico: () => _irPara(_Aba.historico),
            aoVerParadas: () => _irPara(_Aba.paradas),
            aoVerRelatorio: () => _irPara(_Aba.relatorio),
            aoVerEquipe: () => _irPara(_Aba.equipe),
            aoVerRegistrosDosUsuarios: () => _irPara(_Aba.registrosDosUsuarios),
            aoVerAtualizacoes: _abrirAtualizacoes,
            aoVerComoUsar: () => _irPara(_Aba.comoUsar),
          ),
        _Aba.historico => HistoricoPage(usuario: widget.usuario),
        _Aba.registro => RegistroPage(
            formulario: _formulario,
            usuario: widget.usuario,
            cameras: widget.cameras,
          ),
        // O mapa fica sempre montado (no Offstage do build).
        _Aba.mapa => null,
        _Aba.paradas => ParalisacoesPage(
            usuario: widget.usuario,
            aoMudar: _atualizarParadoAgora,
          ),
        _Aba.relatorio => RelatorioPage(usuario: widget.usuario),
        _Aba.equipe => SupervisorPage(usuario: widget.usuario),
        _Aba.registrosDosUsuarios => const RegistrosDosUsuariosPage(),
        _Aba.comoUsar => TutorialPage(
            nomeUsuario: widget.usuario.nome,
            ehSupervisor: _ehSupervisor,
          ),
      };

  String get _tituloDaAba => switch (_aba) {
        _Aba.inicio => 'RDO cbm',
        _Aba.historico => 'Histórico',
        _Aba.registro => 'Novo registro',
        _Aba.mapa => 'Mapa',
        _Aba.paradas => 'Paradas',
        _Aba.relatorio => 'Relatório do dia',
        _Aba.equipe => 'Equipe',
        _Aba.registrosDosUsuarios => 'Registros dos usuários',
        _Aba.comoUsar => 'Como usar o app',
      };

  PreferredSizeWidget _barraDoTopo() {
    // Ao lado das iniciais do usuário, o botão de claro/escuro.
    final acoes = [
      const BotaoDoTema(),
      MenuDaConta(usuario: widget.usuario, aoSair: widget.aoSair),
    ];

    if (_aba == _Aba.inicio) {
      final nome = widget.usuario.nome.trim();
      return AppBar(
        toolbarHeight: 68,
        title: SaudacaoDoInicio(
          filial: Dependencias.filial.codigo,
          saudacao: saudacao(DateTime.now()),
          primeiroNome: nome.isEmpty ? '' : nome.split(' ').first,
        ),
        actions: acoes,
      );
    }

    // No registro, a barra mostra a etapa e a seta volta do Serviço ao Local.
    if (_aba == _Aba.registro) {
      return PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 34),
        child: ListenableBuilder(
          listenable: _formulario,
          builder: (context, _) => AppBar(
            leading: _formulario.etapa == EtapaDoRegistro.servico
                ? BackButton(onPressed: _formulario.voltar)
                : null,
            title: Text(_tituloDaAba),
            actions: acoes,
            bottom: ProgressoDasEtapas(etapa: _formulario.etapa),
          ),
        ),
      );
    }

    return AppBar(title: Text(_tituloDaAba), actions: acoes);
  }

  @override
  Widget build(BuildContext context) {
    final tela = _telaDaAba();
    // Com o teclado aberto, o botão do meio sairia flutuando sobre ele.
    final tecladoAberto = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: _aba == _Aba.inicio,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _aoVoltar();
      },
      child: Scaffold(
        appBar: _barraDoTopo(),
        floatingActionButton: tecladoAberto
            ? null
            : FloatingActionButton(
                tooltip: 'Novo registro',
                onPressed: () => _irPara(_Aba.registro),
                child: const Icon(Icons.photo_camera_outlined, size: 28),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BarraDeNavegacao(
          selecionado: _itemDaBarra,
          aoEscolher: _escolherNaBarra,
          alertaNoMais: _paradoAgora,
        ),
        // expand: o tamanho do Stack é o da tela toda. Sem isso ele mede pelo
        // mapa escondido (Offstage, tamanho zero) e a aba some.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Minimapa fora da tela: pré-carrega os tiles para a câmera.
            Positioned(
              left: -300,
              top: -300,
              child: SizedBox(
                width: 256,
                height: 256,
                child: criarWidgetMiniMapa(locAtual),
              ),
            ),
            // Mapa sempre montado: a aba abre sem recarregar.
            Offstage(
              offstage: _aba != _Aba.mapa,
              child: const MapPage(),
            ),
            if (tela != null) tela,
          ],
        ),
      ),
    );
  }
}
