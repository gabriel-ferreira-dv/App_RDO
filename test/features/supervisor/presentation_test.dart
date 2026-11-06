import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:namer_app/core/obra/dia_de_trabalho.dart';
import 'package:namer_app/features/auth/models/usuario.dart';
import 'package:namer_app/features/mapa/domain/entities/estaca_navegavel.dart';
import 'package:namer_app/features/relatorio/domain/entities/funcao_equipe.dart';
import 'package:namer_app/features/supervisor/domain/entities/encarregado_da_equipe.dart';
import 'package:namer_app/features/supervisor/domain/entities/foto_consolidada.dart';
import 'package:namer_app/features/supervisor/domain/entities/registro_da_equipe.dart';
import 'package:namer_app/features/supervisor/domain/entities/resumo_do_encarregado.dart';
import 'package:namer_app/features/supervisor/domain/usecases/baixar_fotos_do_consolidado.dart';
import 'package:namer_app/features/supervisor/domain/usecases/carregar_dia_da_equipe.dart';
import 'package:namer_app/features/supervisor/presentation/pages/supervisor_page.dart';
import 'package:namer_app/features/supervisor/presentation/viewmodels/mapa_avanco_view_model.dart';
import 'package:namer_app/features/supervisor/presentation/viewmodels/montar_equipe_view_model.dart';
import 'package:namer_app/features/supervisor/presentation/viewmodels/supervisor_view_model.dart';

import 'fakes.dart';

// O que o gerador de PDF recebeu (o PDF de verdade tem teste próprio).
class _PdfFalso {
  List<List<FotoConsolidada>>? fotos;
  DateTime? dia;
  bool falhar = false;

  // Segura a geração até o teste soltar.
  Completer<void>? segurar;

  Future<Uint8List> call({
    required List<ResumoDoEncarregado> resumos,
    required List<List<FotoConsolidada>> fotos,
    required String supervisor,
    required DateTime dia,
  }) async {
    await segurar?.future;
    if (falhar) throw Exception('PDF');
    this.fotos = fotos;
    this.dia = dia;
    return Uint8List.fromList([1, 2, 3]);
  }
}

void main() {
  late EquipeFalsa equipe;
  late RegistrosFalsos registros;
  late _PdfFalso pdf;

  SupervisorViewModel supervisor({
    bool Function()? noturno,
    DateTime Function()? agora,
    Future<void> Function()? prepararSessao,
  }) =>
      SupervisorViewModel(
        equipe: equipe,
        registros: registros,
        carregarDia: CarregarDiaDaEquipe(registros, ehNoturno: (_) => false),
        baixarFotos: BaixarFotosDoConsolidado(registros),
        gerarPdf: pdf.call,
        matricula: () => '9001',
        supervisorNome: 'Carla',
        relogio: RelogioDoTurno(
            agora: agora ?? () => agoraDeTeste, noturno: noturno ?? () => false),
        prepararSessao: prepararSessao,
      );

  setUp(() {
    equipe = EquipeFalsa()..equipes = {'9001': [ana, joao]};
    registros = RegistrosFalsos()
      ..registros = [
        registroDaEquipe(ana.matricula, DateTime(2026, 9, 24, 8, 10),
            nome: 'Ana Lima'),
        registroDaEquipe(ana.matricula, DateTime(2026, 9, 22, 9), idLocal: 2),
      ]
      ..paradas = [parada(joao.matricula, DateTime(2026, 9, 24, 13))]
      ..efetivo = {
        ana.matricula: const [FuncaoEquipe(funcao: 'Servente', quantidade: 11)]
      };
    pdf = _PdfFalso();
  });

  group('Painel do supervisor', () {
    test('carrega o dia de cada encarregado e monta o cartão uma vez', () async {
      final vm = supervisor();
      expect(vm.carregando, isTrue);
      await vm.carregar();

      expect(vm.carregando, isFalse);
      expect(vm.temEquipe, isTrue);
      expect(vm.matriculasDoMapa, ['051395', '045020', '9001']);
      final [daAna, doJoao] = vm.cartoes;
      expect(daAna.subtitulo, '11 no efetivo · 1 atividade(s)');
      expect(doJoao.subtitulo, '0 no efetivo · 0 atividade(s) · PARADO AGORA');
      expect(daAna.registros.single.linha,
          '08:10 · C1 / KM 225 · Terraplenagem — COMPACTAÇÃO DE ATERRO');
      expect(daAna.ultimoRegistro, 'Último registro às 08:10');
      expect(doJoao.ultimoRegistro, isNull);
      // Os textos ficam prontos: ler de novo não remonta nada.
      expect(vm.cartoes, same(vm.cartoes));
    });

    test('trocar o dia busca de novo; depois de hoje volta a hoje', () async {
      final vm = supervisor();
      await vm.carregar();
      vm.mudarDia(DateTime(2026, 9, 22));
      await pumpEventQueue();
      expect(vm.dia, DateTime(2026, 9, 22));
      expect(vm.cartoes.first.registros.single.registro.idLocal, 2);

      vm.mudarDia(DateTime(2026, 9, 30));
      await pumpEventQueue();
      expect(vm.dia, DateTime(2026, 9, 24));
    });

    test('supervisor da noite: às 2h ainda é o dia anterior', () {
      final vm = supervisor(
          noturno: () => true, agora: () => DateTime(2026, 9, 25, 2));
      expect(vm.dia, DateTime(2026, 9, 24));
    });

    // Supervisor recém-incluído no turno da noite, abrindo a aba à 1h: o
    // aparelho ainda o achava do dia, e a lista que chega ao renovar a sessão
    // muda o "hoje" de 25 para 24. Antes a busca era descartada e a tela
    // ficava girando para sempre.
    test('o turno que chega ao renovar a sessão não deixa a tela girando',
        () async {
      var noturno = false;
      final vm = supervisor(
        noturno: () => noturno,
        agora: () => DateTime(2026, 9, 25, 1),
        prepararSessao: () async => noturno = true,
      );
      await vm.carregar();
      expect(vm.carregando, isFalse);
      expect(vm.dia, DateTime(2026, 9, 24));
      expect(vm.cartoes, hasLength(2));
    });

    test('só a busca mais nova mexe na tela', () async {
      final primeira = Completer<void>();
      var sessoes = 0;
      final vm = supervisor(
          prepararSessao: () => ++sessoes == 1 ? primeira.future : Future.value());
      final carregando = vm.carregar();
      vm.mudarDia(DateTime(2026, 9, 22));
      await pumpEventQueue();
      expect(vm.dia, DateTime(2026, 9, 22));
      expect(vm.carregando, isFalse);

      // A primeira termina depois e é descartada.
      primeira.complete();
      await carregando;
      expect(vm.dia, DateTime(2026, 9, 22));
      expect(vm.carregando, isFalse);
    });

    test('virada do dia com a tela aberta: o rótulo continua o dos cartões',
        () async {
      var agora = DateTime(2026, 9, 24, 23, 50);
      final vm = supervisor(agora: () => agora);
      await vm.carregar();
      agora = DateTime(2026, 9, 25, 0, 10);
      expect(vm.hoje, DateTime(2026, 9, 25));
      expect(vm.dia, DateTime(2026, 9, 24));

      // O "dia seguinte" do seletor leva ao novo hoje.
      vm.mudarDia(DateTime(2026, 9, 25));
      await pumpEventQueue();
      expect(vm.dia, DateTime(2026, 9, 25));
    });

    test('relatório sem fotos não baixa nada', () async {
      final vm = supervisor();
      await vm.carregar();
      final relatorio = await vm.gerarRelatorio();
      expect(relatorio, isNotNull);
      expect(pdf.fotos, [isEmpty, isEmpty]);
      expect(pdf.dia, DateTime(2026, 9, 24));
      expect(registros.downloads, 0);
      expect(relatorio!.arquivo, 'equipe_20260924.pdf');
    });

    // O relatório com fotos demora; trocar o dia no meio não pode dar ao PDF
    // de 24/09 o título e o nome de arquivo de outro dia.
    test('o PDF sai com o dia em que foi pedido, mesmo trocando o dia no meio',
        () async {
      final vm = supervisor();
      await vm.carregar();
      pdf.segurar = Completer();
      final gerando = vm.gerarRelatorio();
      vm.mudarDia(DateTime(2026, 9, 23));
      await pumpEventQueue();
      expect(vm.dia, DateTime(2026, 9, 23));

      pdf.segurar!.complete();
      final relatorio = await gerando;
      expect(pdf.dia, DateTime(2026, 9, 24));
      expect(relatorio!.titulo, 'Equipe — 24/09/2026');
      expect(relatorio.arquivo, 'equipe_20260924.pdf');
    });

    test('relatório com fotos mostra o progresso do download', () async {
      final r = registros.registros.first;
      registros
        ..fotosDosRegistros = {r.chave: ['a.jpg', 'b.jpg']}
        ..arquivos = {
          'a.jpg': Uint8List.fromList([1]),
          'b.jpg': Uint8List.fromList([2]),
        };
      final vm = supervisor();
      await vm.carregar();
      vm.definirIncluirFotos(true);
      final rotulos = <String>{};
      vm.addListener(() => rotulos.add(vm.rotuloDoRelatorio));

      await vm.gerarRelatorio();
      expect(rotulos, contains('Baixando fotos 0 de 2…'));
      expect(pdf.fotos![0], hasLength(2));
      expect(vm.gerando, isFalse);
      expect(vm.rotuloDoRelatorio, 'Gerar relatório da equipe');
    });

    test('relatório que falha volta null e libera o botão', () async {
      pdf.falhar = true;
      final vm = supervisor();
      await vm.carregar();
      expect(await vm.gerarRelatorio(), isNull);
      expect(vm.gerando, isFalse);
    });

    test('corrigir manda para o servidor e recarrega; erro só avisa', () async {
      final vm = supervisor();
      await vm.carregar();
      final alvo = vm.cartoes.first.registros.single.registro;
      expect(await vm.corrigir(alvo, alvo.campos), startsWith('Registro corrigido'));
      expect(registros.corrigidos.keys, [alvo.chave]);

      registros.erroAoCorrigir = 'Sem permissão para corrigir este registro';
      expect(await vm.corrigir(alvo, alvo.campos),
          'Sem permissão para corrigir este registro');
    });
  });

  group('Montar a equipe', () {
    const maria = EncarregadoDaEquipe(matricula: '070001', nome: 'Maria Júlia');
    const ferias = EncarregadoDaEquipe(matricula: '060000', nome: 'Pedro');

    test('a busca ignora acento; quem está na equipe sem apontamento aparece',
        () async {
      equipe.recentes = [ana, joao, maria];
      final vm = MontarEquipeViewModel(
          repositorio: equipe, supervisorMatricula: '9001', equipeAtual: [ferias]);
      await vm.carregar();

      expect(vm.visiveis, [ana, joao, maria, ferias]);
      expect(vm.subtituloDe(ferias),
          'Matrícula 060000 · sem apontamento nos últimos dias');
      expect(vm.subtituloDe(ana), 'Matrícula 051395');

      vm.definirFiltro('joao');
      expect(vm.visiveis, [joao]);
      vm.definirFiltro('');
      vm.marcar(ana, true);
      expect(vm.selecionados, '2 selecionado(s)');

      final salvo = await vm.salvar();
      expect(salvo.erro, isNull);
      expect(salvo.equipe, [ana, ferias]);
    });

    // Antes quem não tinha apontamento recente ficava marcado e invisível:
    // não dava para tirar da equipe (e o acesso aos registros dele seguia).
    test('quem não aparece no apontamento pode sair da equipe', () async {
      equipe.recentes = [ana];
      final vm = MontarEquipeViewModel(
          repositorio: equipe, supervisorMatricula: '9001', equipeAtual: [ana, ferias]);
      await vm.carregar();
      vm.marcar(ferias, false);
      expect((await vm.salvar()).equipe, [ana]);
    });

    test('erro ao salvar fica na tela', () async {
      equipe.erroAoSalvar = 'Não foi possível salvar a equipe';
      final vm = MontarEquipeViewModel(
          repositorio: equipe, supervisorMatricula: '9001', equipeAtual: const []);
      await vm.carregar();
      final salvo = await vm.salvar();
      expect(salvo.equipe, isNull);
      expect(salvo.erro, 'Não foi possível salvar a equipe');
      expect(vm.salvando, isFalse);
    });
  });

  group('Mapa de avanço', () {
    // Estacas 1115 a 1117 do C1, a 20 m uma da outra.
    final estacas = [
      for (var n = 1115; n <= 1117; n++)
        EstacaNavegavel(
          trecho: 'C1',
          km: '225',
          rotulo: 'EST. $n',
          numero: n,
          ponto: LatLng(-19.9 + (n - 1115) * 0.00018, -40.4),
        ),
    ];
    final daEquipe = <RegistroDaEquipe>[
      registroDaEquipe(ana.matricula, DateTime(2026, 9, 20),
          nome: 'Ana Lima', estacaFinal: 'EST. 1117', quantidade: 120, unidade: 'm³'),
      registroDaEquipe(ana.matricula, DateTime(2026, 9, 21),
          idLocal: 2, nome: 'Ana Lima', servico: 'DRENAGEM'),
      registroDaEquipe(joao.matricula, DateTime(2026, 9, 22),
          idLocal: 3, nome: 'João Souza', servico: 'DRENAGEM', estacaInicial: ''),
    ];

    MapaAvancoViewModel mapaDaEquipe() => MapaAvancoViewModel(
          estacasDoProjeto: () async => estacas,
          registrosDaEquipe: (desde) => registros
              .registrosDoPeriodo(['051395', '045020'], desde: desde),
          relogio: RelogioDoTurno(agora: () => agoraDeTeste),
        );

    test('filtra, conta e guarda as contas até algo mudar', () async {
      registros.doPeriodo = daEquipe;
      final vm = mapaDaEquipe();
      await vm.carregar();

      expect(registros.periodosPedidos.single, DateTime(2026, 8, 26));
      expect(vm.servicos, ['DRENAGEM', 'COMPACTAÇÃO DE ATERRO']);
      expect(vm.tituloDoResumo, '3 registro(s) · 2 serviço(s)');
      expect(vm.dicaDoResumo, contains('1 registro(s) sem estaca'));
      expect(vm.tracos, hasLength(2));
      expect(vm.pontosFiltrados, hasLength(4));
      expect(vm.resumo, same(vm.resumo));
      expect(vm.tracos, same(vm.tracos));
      expect(vm.encarregados, same(vm.encarregados));

      final antes = vm.tracos;
      vm.escolherServico('DRENAGEM');
      expect(vm.tracos, isNot(same(antes)));
      expect(vm.filtrados, hasLength(2));
      // A Ana tem drenagem: o filtro de serviço fica. O João não tem
      // compactação: aí o serviço volta para todos.
      vm.escolherEncarregado(ana.matricula);
      expect(vm.servico, 'DRENAGEM');
      expect(vm.filtrados.single.idLocal, 2);
      vm.escolherServico('COMPACTAÇÃO DE ATERRO');
      vm.escolherEncarregado(joao.matricula);
      expect(vm.servico, isNull);
      expect(vm.encarregados.map((e) => e.nome), ['Ana Lima', 'João Souza']);
    });

    test('o detalhe usa os mesmos textos do resto do app', () async {
      registros.doPeriodo = daEquipe;
      final vm = mapaDaEquipe();
      await vm.carregar();
      expect(vm.subtituloDoDetalhe(daEquipe.first),
          'C1 / KM 225 · Est. EST. 1115 a EST. 1117\n'
          'Ana Lima · 20/09/2026 às 00:00 · 120 m³');
    });

    test('trocar o período busca de novo; sem resposta, avisa', () async {
      registros.doPeriodo = daEquipe;
      final vm = mapaDaEquipe();
      await vm.carregar();
      registros.doPeriodo = null;
      await vm.escolherPeriodo(PeriodoDoMapa.tudo);
      expect(registros.periodosPedidos.last, isNull);
      expect(vm.erro, contains('internet'));
    });

    // Antes um erro aqui deixava o mapa girando para sempre, sem o botão
    // "Tentar de novo".
    test('erro nas estacas ou no aparelho não deixa o mapa girando', () async {
      final semEstacas = MapaAvancoViewModel(
        estacasDoProjeto: () async => throw Exception('CSV'),
        registrosDaEquipe: (desde) async => daEquipe,
      );
      await semEstacas.carregar();
      expect(semEstacas.carregando, isFalse);
      expect(semEstacas.erro, contains('Tente de novo'));

      final semBanco = MapaAvancoViewModel(
        estacasDoProjeto: () async => estacas,
        registrosDoDia: (_) async => throw StateError('banco'),
      );
      await semBanco.carregar();
      expect(semBanco.semNadaAinda, isFalse);
      expect(semBanco.erro, isNotNull);
    });

    test('do encarregado: o dia, do aparelho', () async {
      final dias = <DateTime>[];
      final vm = MapaAvancoViewModel(
        estacasDoProjeto: () async => estacas,
        registrosDoDia: (dia) async {
          dias.add(dia);
          return [daEquipe.first];
        },
        relogio: RelogioDoTurno(
            agora: () => DateTime(2026, 9, 25, 2), noturno: () => true),
      );
      expect(vm.titulo, 'Mapa do dia');
      expect(vm.dia, DateTime(2026, 9, 24));
      await vm.carregar();
      await vm.mudarDia(DateTime(2026, 9, 23, 18));
      expect(dias, [DateTime(2026, 9, 24), DateTime(2026, 9, 23)]);
      expect(vm.tituloDoResumo, '1 registro(s) · 1 serviço(s)');
    });
  });

  group('Tela do supervisor', () {
    final usuario = Usuario(
        id: 1,
        nome: 'Carla',
        email: 'carla@cbm.com',
        senhaHash: '',
        matricula: '9001',
        criadoEm: '');

    testWidgets('equipe vazia explica o que fazer', (tester) async {
      equipe.equipes = {};
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SupervisorPage(usuario: usuario, viewModel: supervisor())),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sua equipe ainda está vazia'), findsOneWidget);
      expect(find.text('Mapa de avanço da equipe'), findsNothing);
    });

    testWidgets('com equipe: um cartão por encarregado e o botão do relatório',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SupervisorPage(usuario: usuario, viewModel: supervisor())),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ana Lima'), findsOneWidget);
      expect(find.text('João Souza'), findsOneWidget);
      expect(find.text('Hoje, 24/09/2026'), findsOneWidget);
      expect(find.text('Gerar relatório da equipe'), findsOneWidget);
    });
  });
}
