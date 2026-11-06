import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/auth/models/usuario.dart';
import 'package:namer_app/features/historico/data/repositories/historico_repository_impl.dart';
import 'package:namer_app/features/historico/domain/entities/item_do_historico.dart';
import 'package:namer_app/features/historico/presentation/pages/historico_page.dart';
import 'package:namer_app/features/historico/presentation/viewmodels/historico_view_model.dart';

import 'fakes.dart';

HistoricoViewModel _vm(RepositorioFalso repositorio,
        {VoidCallback? aoCorrigir}) =>
    HistoricoViewModel(
      repositorio: repositorio,
      usuarioId: 1,
      aoCorrigir: aoCorrigir,
      agora: () => agoraDeTeste,
    );

List<String> _textos(List<LinhaDoHistorico> linhas) => [
      for (final l in linhas)
        switch (l) {
          CabecalhoDoDia(:final texto) => '# $texto',
          RegistroNaLista(:final item) => '${item.registro.registroId}',
        },
    ];

void main() {
  late RepositorioFalso repositorio;

  setUp(() {
    repositorio = RepositorioFalso()
      ..grupos = [
        grupo([
          registro(1, DateTime(2026, 7, 15, 7, 31)),
          registro(2, DateTime(2026, 7, 14, 9)),
          registro(3, DateTime(2026, 7, 14, 16)),
        ]),
      ];
  });

  group('ViewModel', () {
    test('hoje: só os registros, sem cabeçalho', () async {
      final vm = _vm(repositorio);
      expect(vm.carregando, isTrue);
      await vm.carregar();
      expect(vm.carregando, isFalse);
      expect(_textos(vm.linhas), ['1']);
    });

    test('7 dias: um cabeçalho por dia, do mais recente', () async {
      final vm = _vm(repositorio);
      await vm.carregar();
      vm.escolherPeriodo(PeriodoDoHistorico.semana);
      expect(_textos(vm.linhas), ['# Hoje', '1', '# Ontem', '3', '2']);
    });

    test('período vazio: mensagem e "Ver todos" até chegar em Tudo', () async {
      repositorio.grupos = [];
      final vm = _vm(repositorio);
      await vm.carregar();
      expect(vm.linhas, isEmpty);
      expect(vm.periodo.semRegistros, 'Nenhum registro hoje');
      expect(vm.podeVerTodos, isTrue);
      vm.verTodos();
      expect(vm.periodo, PeriodoDoHistorico.tudo);
      expect(vm.podeVerTodos, isFalse);
    });

    test('corrigir grava, manda para o servidor e recarrega', () async {
      var envios = 0;
      final vm = _vm(repositorio, aoCorrigir: () => envios++);
      await vm.carregar();
      final alvo = repositorio.grupos.first.registros.first;

      await vm.corrigir(alvo, camposDeTeste);
      expect(repositorio.corrigidos.keys, [alvo.registroId]);
      expect(envios, 1);
      expect(repositorio.cargas, 2);
      expect(vm.subtituloDaCorrecao(alvo), 'Registro de 15/07/2026 às 07:31');
    });

    test('erro ao carregar: para de girar e avisa; puxar tenta de novo',
        () async {
      repositorio.falharAoCarregar = true;
      final vm = _vm(repositorio);
      await vm.carregar();
      expect(vm.carregando, isFalse);
      expect(vm.falhou, isTrue);
      expect(vm.linhas, isEmpty);

      repositorio.falharAoCarregar = false;
      await vm.carregar();
      expect(vm.falhou, isFalse);
      expect(_textos(vm.linhas), ['1']);
    });

    // A tela fecha o "Refazendo o carimbo" quando corrigir() volta; não pode
    // ficar presa esperando a lista recarregar.
    test('corrigir volta sem esperar a lista recarregar', () async {
      final vm = _vm(repositorio);
      await vm.carregar();
      final alvo = repositorio.grupos.first.registros.first;

      repositorio.segurarCarga = Completer();
      expect(await vm.corrigir(alvo, camposDeTeste), isTrue);
      expect(vm.carregando, isTrue);

      repositorio.segurarCarga!.complete();
      await pumpEventQueue();
      expect(vm.carregando, isFalse);
    });

    test('corrigir não gravou: false, sem mandar nem recarregar', () async {
      var envios = 0;
      final vm = _vm(repositorio, aoCorrigir: () => envios++);
      await vm.carregar();
      final alvo = repositorio.grupos.first.registros.first;

      repositorio.falharAoCorrigir = true;
      expect(await vm.corrigir(alvo, camposDeTeste), isFalse);
      expect(envios, 0);
      expect(repositorio.cargas, 1);
    });

    test('campos para corrigir vêm do repositório', () async {
      repositorio.campos[1] = camposDeTeste;
      final vm = _vm(repositorio);
      final alvo = repositorio.grupos.first.registros.first;
      expect(await vm.camposParaCorrigir(alvo), same(camposDeTeste));
    });
  });

  test('repositório: agrupa as fotos do Registro por atividade', () async {
    final repositorioReal = HistoricoRepositoryImpl(
      fotosDoUsuario: (_) async => [],
      camposDe: (_) async => camposDeTeste,
      editar: (_, __) async {},
    );
    expect(await repositorioReal.gruposDoUsuario(1), isEmpty);
    expect(await repositorioReal.camposDoRegistro(1), same(camposDeTeste));
  });

  group('Tela', () {
    final usuario = Usuario(
        id: 1, nome: 'Ana', email: 'ana@cbm.com', senhaHash: '', criadoEm: '');

    Future<void> abrir(WidgetTester tester, HistoricoViewModel vm) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HistoricoPage(usuario: usuario, viewModel: vm)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o registro de hoje com a situação', (tester) async {
      await abrir(tester, _vm(repositorio));
      expect(find.text('COMPACTAÇÃO DE ATERRO'), findsOneWidget);
      expect(find.text('C1 · est. 1115 – 1120 · 07:31'), findsOneWidget);
      expect(find.text('Enviado'), findsOneWidget);
    });

    testWidgets('sem registro hoje: "Ver todos" leva à lista inteira',
        (tester) async {
      repositorio.grupos = [
        grupo([registro(2, DateTime(2026, 7, 14, 9))]),
      ];
      await abrir(tester, _vm(repositorio));
      expect(find.text('Nenhum registro hoje'), findsOneWidget);

      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      expect(find.text('Ontem'), findsWidgets);
      expect(find.text('COMPACTAÇÃO DE ATERRO'), findsOneWidget);
    });

    testWidgets('erro ao carregar: avisa, e puxar para baixo tenta de novo',
        (tester) async {
      repositorio.falharAoCarregar = true;
      await abrir(tester, _vm(repositorio));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Não foi possível abrir o histórico'), findsOneWidget);

      repositorio.falharAoCarregar = false;
      await tester.fling(
          find.text('Não foi possível abrir o histórico'),
          const Offset(0, 400),
          1000);
      await tester.pumpAndSettle();
      expect(find.text('COMPACTAÇÃO DE ATERRO'), findsOneWidget);
    });
  });
}
