import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/privacidade/domain/entities/aviso_de_privacidade.dart';
import 'package:namer_app/features/privacidade/domain/usecases/carregar_aviso_de_privacidade.dart';
import 'package:namer_app/features/privacidade/domain/usecases/confirmar_leitura_do_aviso.dart';
import 'package:namer_app/features/privacidade/presentation/pages/privacidade_page.dart';
import 'package:namer_app/features/privacidade/presentation/viewmodels/privacidade_view_model.dart';

import 'fakes.dart';

PrivacidadeViewModel _viewModel(RepositorioFalso repositorio,
        {AvisoDePrivacidade? avisoPendente}) =>
    PrivacidadeViewModel(
      carregarAviso: CarregarAvisoDePrivacidade(repositorio),
      confirmarLeitura: ConfirmarLeituraDoAviso(repositorio,
          agora: () => DateTime(2026, 10, 23, 7, 30)),
      filial: '010152',
      email: 'ana@cbm.com',
      avisoPendente: avisoPendente,
    );

void main() {
  group('ViewModel — consulta', () {
    test('carregando → pronto, com o texto e a versão', () async {
      final repositorio = RepositorioFalso()
        ..avisos['010152'] =
            avisoDe('010152', 2, atualizadoEm: DateTime(2026, 10, 22, 10));
      final vm = _viewModel(repositorio);
      final situacoes = <SituacaoDoAviso>[];
      vm.addListener(() => situacoes.add(vm.situacao));

      expect(vm.situacao, SituacaoDoAviso.carregando);
      expect(vm.pedirCiencia, isFalse);
      await vm.carregar();

      expect(situacoes, [SituacaoDoAviso.carregando, SituacaoDoAviso.pronto]);
      expect(vm.versaoEData, 'Versão 2 · atualizado em 22/10/2026');
      expect(vm.linhas.where((l) => l.ehTitulo).map((l) => l.texto),
          ['Em resumo', 'Seus direitos']);
    });

    test('sem aviso: indisponível; tentar de novo depois carrega', () async {
      final repositorio = RepositorioFalso();
      final vm = _viewModel(repositorio);
      await vm.carregar();
      expect(vm.situacao, SituacaoDoAviso.indisponivel);

      repositorio.avisos['010152'] = avisoDe('010152', 1);
      await vm.carregar();
      expect(vm.situacao, SituacaoDoAviso.pronto);
      expect(vm.versaoEData, 'Versão 1');
    });

    test('na consulta, "Li e entendi" não faz nada', () async {
      final repositorio = RepositorioFalso()
        ..avisos['010152'] = avisoDe('010152', 1);
      final vm = _viewModel(repositorio);
      await vm.carregar();
      expect(await vm.confirmar(), isFalse);
      expect(repositorio.ciencias, isEmpty);
    });

    test('fechar a tela no meio da busca não quebra', () async {
      final repositorio = RepositorioFalso()
        ..avisos['010152'] = avisoDe('010152', 1)
        ..segurarBusca = Completer<void>();
      final vm = _viewModel(repositorio);
      final carregando = vm.carregar();
      vm.dispose();
      repositorio.segurarBusca!.complete();
      await carregando;
    });
  });

  group('ViewModel — ciência', () {
    test('já começa pronto, sem buscar de novo', () async {
      final repositorio = RepositorioFalso();
      final vm = _viewModel(repositorio, avisoPendente: avisoDe('010152', 4));
      expect(vm.pedirCiencia, isTrue);
      expect(vm.situacao, SituacaoDoAviso.pronto);
      await vm.carregar();
      expect(repositorio.buscas, 0);
    });

    test('"Li e entendi" guarda a versão uma vez só', () async {
      final repositorio = RepositorioFalso();
      final vm = _viewModel(repositorio, avisoPendente: avisoDe('010152', 4));

      expect(await vm.confirmar(), isTrue);
      expect(vm.confirmando, isTrue);
      expect(repositorio.ciencias['010152|ana@cbm.com']?.versao, 4);
      // Toque duplo não confirma de novo.
      expect(await vm.confirmar(), isFalse);
    });
  });

  group('Tela', () {
    Future<void> abrir(WidgetTester tester, PrivacidadeViewModel vm) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PrivacidadePage(viewModel: vm))),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('consulta: mostra os títulos e deixa voltar', (tester) async {
      final repositorio = RepositorioFalso()
        ..avisos['010152'] = avisoDe('010152', 1);
      await abrir(tester, _viewModel(repositorio));

      expect(find.text('Em resumo'), findsOneWidget);
      expect(find.text('Seus direitos'), findsOneWidget);
      expect(find.text('Li e entendi'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('sem aviso: explica e tenta de novo', (tester) async {
      final repositorio = RepositorioFalso();
      await abrir(tester, _viewModel(repositorio));
      expect(find.textContaining('Não foi possível carregar'), findsOneWidget);

      repositorio.avisos['010152'] = avisoDe('010152', 1);
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(find.text('Em resumo'), findsOneWidget);
    });

    testWidgets('ciência: o voltar não fecha; "Li e entendi" guarda e fecha',
        (tester) async {
      final repositorio = RepositorioFalso();
      await abrir(
          tester, _viewModel(repositorio, avisoPendente: avisoDe('010152', 4)));

      expect(find.byType(BackButton), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Li e entendi'), findsOneWidget);

      await tester.tap(find.text('Li e entendi'));
      await tester.pumpAndSettle();
      expect(find.text('Li e entendi'), findsNothing);
      expect(repositorio.ciencias['010152|ana@cbm.com']?.versao, 4);
    });

    // A rota pode montar a tela de novo (o Navigator redesenha); a tela
    // continua no ViewModel já carregado, sem voltar a girar.
    testWidgets('tela montada de novo: continua no mesmo ViewModel',
        (tester) async {
      final repositorio = RepositorioFalso()
        ..avisos['010152'] = avisoDe('010152', 1);
      final redesenhar = ValueNotifier(0);
      addTearDown(redesenhar.dispose);
      var montagens = 0;
      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder(
          valueListenable: redesenhar,
          // Como o builder antigo da rota: um ViewModel a cada vez.
          builder: (_, __, ___) {
            montagens++;
            return PrivacidadePage(viewModel: _viewModel(repositorio));
          },
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Em resumo'), findsOneWidget);

      redesenhar.value++;
      await tester.pump();
      expect(montagens, 2);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Em resumo'), findsOneWidget);
    });
  });
}
