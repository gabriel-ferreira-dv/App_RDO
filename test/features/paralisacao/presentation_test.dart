import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/obra/dia_de_trabalho.dart';
import 'package:namer_app/features/auth/models/usuario.dart';
import 'package:namer_app/features/paralisacao/domain/usecases/carregar_paralisacoes_do_dia.dart';
import 'package:namer_app/features/paralisacao/domain/usecases/retomar_servico.dart';
import 'package:namer_app/features/paralisacao/domain/usecases/salvar_paralisacao.dart';
import 'package:namer_app/features/paralisacao/presentation/pages/paralisacao_form_page.dart';
import 'package:namer_app/features/paralisacao/presentation/viewmodels/paralisacao_form_view_model.dart';
import 'package:namer_app/features/paralisacao/presentation/viewmodels/paralisacoes_do_dia_view_model.dart';
import 'package:namer_app/features/paralisacao/presentation/viewmodels/paralisacoes_view_model.dart';
import 'package:namer_app/features/paralisacao/presentation/widgets/paralisacoes_do_dia.dart';

import 'fakes.dart';

ParalisacoesDoDiaViewModel _doDia(RepositorioFalso repositorio,
        {DateTime? dia, VoidCallback? aoMudarDados}) =>
    ParalisacoesDoDiaViewModel(
      carregarDoDia: CarregarParalisacoesDoDia(repositorio),
      retomarServico: RetomarServico(repositorio, agora: () => agoraDeTeste),
      usuarioId: 1,
      relogio: RelogioDoTurno(agora: () => agoraDeTeste),
      dia: dia,
      aoMudarDados: aoMudarDados,
    );

ParalisacaoFormViewModel _formulario(
  RepositorioFalso repositorio, {
  DateTime? dia,
  bool noturno = false,
  int? existente,
}) =>
    ParalisacaoFormViewModel(
      salvarParalisacao: SalvarParalisacao(repositorio),
      repositorio: repositorio,
      carregarTrechos: () async => ['C1', 'D2'],
      carregarKms: (trecho) async => trecho == 'C1' ? ['224', '225'] : ['230'],
      usuarioId: 1,
      dia: dia ?? DateTime(2026, 9, 24),
      noturno: noturno,
      existente: existente == null
          ? null
          : repositorio.paralisacoes.firstWhere((p) => p.id == existente),
      agora: () => agoraDeTeste,
    );

void main() {
  group('Paralisações do dia', () {
    test('hoje: título, tempo parado e as listas', () async {
      final repositorio = RepositorioFalso();
      await repositorio.salvar(parada(
          inicio: DateTime(2026, 9, 24, 8), fim: DateTime(2026, 9, 24, 9, 30)));
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 24, 14, 5)));
      final vm = _doDia(repositorio);

      expect(vm.carregando, isTrue);
      await vm.carregar();
      expect(vm.carregando, isFalse);
      expect(vm.titulo, 'Paralisações de hoje');
      expect(vm.totalParado, '1h30 parado');
      expect(vm.paradoDesde(vm.resumo.emAndamento.single),
          'Serviço parado desde 14:05 · Chuva');
    });

    test('outro dia, sem paralisação: outro título e outra mensagem', () async {
      final vm = _doDia(RepositorioFalso(), dia: DateTime(2026, 9, 20));
      await vm.carregar();
      expect(vm.ehHoje, isFalse);
      expect(vm.titulo, 'Paralisações do dia');
      expect(vm.totalParado, '');
      expect(vm.semParalisacoes, 'Nenhuma paralisação registrada neste dia.');
    });

    test('retomar fecha, recarrega, avisa e diz quanto parou', () async {
      final repositorio = RepositorioFalso();
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 24, 14)));
      var avisos = 0;
      final vm = _doDia(repositorio, aoMudarDados: () => avisos++);
      await vm.carregar();

      final mensagem = await vm.retomar(vm.resumo.emAndamento.single);
      expect(mensagem, 'Serviço retomado. Parado por 1h.');
      expect(vm.resumo.emAndamento, isEmpty);
      expect(avisos, 1);
    });
  });

  group('Formulário', () {
    test('nova hoje: começa agora e ainda parada', () {
      final vm = _formulario(RepositorioFalso());
      expect(vm.titulo, 'Registrar paralisação');
      expect(vm.rotuloInicio, 'Parou: 15:00');
      expect(vm.rotuloFim, 'Voltou: --:--');
      expect(vm.aindaParado, isTrue);
      expect(vm.rotuloDaFoto, 'Salvar e tirar foto');
    });

    test('nova em outro dia: 13h às 14h para ajustar', () {
      final vm = _formulario(RepositorioFalso(), dia: DateTime(2026, 9, 20));
      expect(vm.rotuloInicio, 'Parou: 13:00');
      expect(vm.rotuloFim, 'Voltou: 14:00');
      expect(vm.detalheNoCarimbo, 'Parado das 13:00 às 14:00');
    });

    test('voltou antes da hora em que parou: é no dia seguinte', () {
      final vm = _formulario(RepositorioFalso(), dia: DateTime(2026, 9, 20));
      vm.definirInicio(22, 30);
      vm.definirFim(1, 0);
      expect(vm.fim, DateTime(2026, 9, 21, 1));
      expect(vm.avisoDeOutroDia, 'Voltou no dia 21/09');
    });

    test('turno da noite: hora da madrugada vai para o dia seguinte', () {
      final vm = _formulario(RepositorioFalso(),
          dia: DateTime(2026, 9, 20), noturno: true);
      vm.definirInicio(1, 15);
      expect(vm.inicio, DateTime(2026, 9, 21, 1, 15));
    });

    test('ligar e desligar "ainda parado"', () {
      final vm = _formulario(RepositorioFalso());
      vm.definirInicio(14, 0);
      vm.definirAindaParado(false);
      // Agora (15h) é depois do início: sugere agora.
      expect(vm.fim, agoraDeTeste);
      vm.definirAindaParado(true);
      expect(vm.fim, isNull);
    });

    test('ao abrir: trechos e a sugestão do último registro', () async {
      final repositorio = RepositorioFalso()
        ..ultimoLocal = (trecho: 'C1', km: '225');
      final vm = _formulario(repositorio);
      await vm.iniciar();
      expect(vm.trechos, ['C1', 'D2']);
      expect(vm.trecho, 'C1');
      expect(vm.km, '225');
      expect(vm.kms, ['224', '225']);
    });

    test('ao abrir: a sugestão não espera a planilha dos trechos', () async {
      final repositorio = RepositorioFalso()
        ..ultimoLocal = (trecho: 'C1', km: '225');
      final planilha = Completer<List<String>>();
      final vm = ParalisacaoFormViewModel(
        salvarParalisacao: SalvarParalisacao(repositorio),
        repositorio: repositorio,
        carregarTrechos: () => planilha.future,
        carregarKms: (trecho) async => ['224', '225'],
        usuarioId: 1,
        dia: DateTime(2026, 9, 24),
        agora: () => agoraDeTeste,
      );
      final abrindo = vm.iniciar();
      await pumpEventQueue();
      expect(vm.trecho, 'C1');
      expect(vm.km, '225');

      planilha.complete(['C1', 'D2']);
      await abrindo;
      expect(vm.trechos, ['C1', 'D2']);
    });

    test('trocar o trecho limpa o KM e traz os KMs do novo', () async {
      final repositorio = RepositorioFalso()
        ..ultimoLocal = (trecho: 'C1', km: '225');
      final vm = _formulario(repositorio);
      await vm.iniciar();
      await vm.escolherTrecho('D2');
      expect(vm.km, isNull);
      expect(vm.kms, ['230']);
    });

    test('salvar sem motivo avisa; com motivo grava e vira edição', () async {
      final repositorio = RepositorioFalso();
      final vm = _formulario(repositorio);

      final semMotivo = await vm.salvar();
      expect(
          (semMotivo as NaoSalvou).problema, 'Escolha o motivo da paralisação');
      expect(vm.salvando, isFalse);

      vm.escolherMotivo('Chuva');
      vm.definirObservacao('pista alagada');
      expect(await vm.salvar(), isA<Salvou>());
      expect(vm.jaGravada, isTrue);
      expect(vm.titulo, 'Paralisação');
      expect(repositorio.paralisacoes.single.observacao, 'pista alagada');
    });

    test('editar uma existente traz os dados e as fotos', () async {
      final repositorio = RepositorioFalso();
      await repositorio.salvar(parada(
          inicio: DateTime(2026, 9, 24, 13),
          fim: DateTime(2026, 9, 24, 14),
          trecho: 'D2',
          observacao: 'barro'));
      await repositorio.adicionarFoto(
          paralisacaoId: 1, caminhoArquivo: 'a.jpg', quando: agoraDeTeste);

      final vm = _formulario(repositorio, existente: 1);
      await vm.iniciar();
      expect(vm.motivo, 'Chuva');
      expect(vm.trecho, 'D2');
      expect(vm.observacao, 'barro');
      expect(vm.caminhosDasFotos, ['a.jpg']);
      expect(vm.rotuloDaFoto, 'Salvar e tirar mais fotos');

      await vm.registrarFoto('b.jpg');
      await vm.recarregarFotos();
      expect(vm.caminhosDasFotos, ['a.jpg', 'b.jpg']);

      await vm.excluir();
      expect(repositorio.excluidas, {1});
    });
  });

  group('Aba Paradas', () {
    test('"hoje" respeita o turno da noite e não passa de hoje', () {
      final madrugada = DateTime(2026, 9, 25, 2);
      final vm = ParalisacoesViewModel(
          relogio: RelogioDoTurno(agora: () => madrugada, noturno: () => true));
      expect(vm.dia, DateTime(2026, 9, 24));

      vm.mudarDia(DateTime(2026, 9, 22));
      expect(vm.dia, DateTime(2026, 9, 22));
      vm.mudarDia(DateTime(2026, 9, 30));
      expect(vm.dia, DateTime(2026, 9, 24));
    });

    // A lista do turno da noite chega do servidor depois de a aba abrir: às
    // 2h, "hoje" passa a ser a noite anterior, sem precisar reabrir a aba.
    test('turno da noite chegou depois: "hoje" refaz a conta', () {
      final madrugada = DateTime(2026, 9, 25, 2);
      var noturno = false;
      final turno = ValueNotifier(0);
      final vm = ParalisacoesViewModel(
        relogio: RelogioDoTurno(agora: () => madrugada, noturno: () => noturno),
        mudancasNoTurno: turno,
      );
      var avisos = 0;
      vm.addListener(() => avisos++);
      expect(vm.dia, DateTime(2026, 9, 25));

      noturno = true;
      turno.value++;
      expect(avisos, 1);
      expect(vm.dia, DateTime(2026, 9, 24));

      // Um dia escolhido antes de hoje fica como está.
      vm.mudarDia(DateTime(2026, 9, 22));
      noturno = false;
      turno.value++;
      expect(vm.dia, DateTime(2026, 9, 22));

      // Depois de descartado, para de ouvir.
      vm.dispose();
      turno.value++;
      expect(avisos, 3);
    });

    test('cartão do dia: lê o turno da noite a cada carga', () async {
      final repositorio = RepositorioFalso();
      // Parou às 2h do dia 25: no turno da noite, é do dia 24.
      await repositorio.salvar(parada(
          inicio: DateTime(2026, 9, 25, 2), fim: DateTime(2026, 9, 25, 3)));
      var noturno = false;
      final vm = ParalisacoesDoDiaViewModel(
        carregarDoDia: CarregarParalisacoesDoDia(repositorio),
        retomarServico: RetomarServico(repositorio),
        usuarioId: 1,
        relogio: RelogioDoTurno(
            agora: () => DateTime(2026, 9, 25, 4), noturno: () => noturno),
        dia: DateTime(2026, 9, 24),
      );
      await vm.carregar();
      expect(vm.resumo.semParalisacoes, isTrue);

      noturno = true;
      await vm.carregar();
      expect(vm.resumo.lista, hasLength(1));
    });
  });

  group('Telas', () {
    final usuario = Usuario(
        id: 1, nome: 'Ana', email: 'ana@cbm.com', senhaHash: '', criadoEm: '');

    testWidgets('cartão: parado agora → "Retomar serviço" avisa e some',
        (tester) async {
      final repositorio = RepositorioFalso();
      await repositorio.salvar(
          parada(inicio: DateTime(2026, 9, 24, 14), trecho: 'C1', km: '225'));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ParalisacoesDoDia(
              usuario: usuario, viewModel: _doDia(repositorio)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Serviço parado desde 14:00 · Chuva'), findsOneWidget);
      expect(find.text('C1 / KM 225'), findsOneWidget);

      await tester.tap(find.text('Retomar serviço'));
      await tester.pumpAndSettle();
      expect(find.text('Serviço retomado. Parado por 1h.'), findsOneWidget);
      expect(find.text('Retomar serviço'), findsNothing);
    });

    testWidgets('formulário: sem motivo avisa; com motivo salva e fecha',
        (tester) async {
      // Tela alta: o formulário inteiro cabe, sem precisar rolar.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repositorio = RepositorioFalso();
      final vm = _formulario(repositorio);
      bool? fechouCom;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => fechouCom = await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(
                      builder: (_) => _telaDoFormulario(vm))),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      final salvar = find.text('Salvar');
      await tester.tap(salvar);
      await tester.pumpAndSettle();
      expect(find.text('Escolha o motivo da paralisação'), findsOneWidget);
      // O aviso some sozinho; antes disso ficaria por cima do botão.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chuva'));
      await tester.pump();
      await tester.tap(salvar);
      await tester.pumpAndSettle();
      expect(fechouCom, isTrue);
      expect(repositorio.paralisacoes.single.motivo, 'Chuva');
    });

    // A rota pode montar a tela de novo (o Navigator redesenha). A tela tem
    // que continuar no ViewModel em uso: um novo viria sem o motivo e sem o
    // id da paralisação já salva, e ela seria gravada duas vezes.
    testWidgets('tela montada de novo: continua no mesmo ViewModel',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repositorio = RepositorioFalso();
      final redesenhar = ValueNotifier(0);
      addTearDown(redesenhar.dispose);
      var montagens = 0;
      bool? fechouCom;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => fechouCom = await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(
                builder: (_) => ValueListenableBuilder(
                  valueListenable: redesenhar,
                  // Como o builder antigo da rota: um ViewModel a cada vez.
                  builder: (_, __, ___) {
                    montagens++;
                    return _telaDoFormulario(_formulario(repositorio));
                  },
                ),
              )),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chuva'));
      await tester.pump();

      redesenhar.value++;
      await tester.pumpAndSettle();
      expect(montagens, 2);
      expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Chuva'))
              .selected,
          isTrue);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(fechouCom, isTrue);
      expect(repositorio.paralisacoes.single.motivo, 'Chuva');
    });
  });
}

Widget _telaDoFormulario(ParalisacaoFormViewModel vm) => ParalisacaoFormPage(
      usuarioId: 1,
      dia: DateTime(2026, 9, 24),
      noturno: false,
      viewModel: vm,
    );
