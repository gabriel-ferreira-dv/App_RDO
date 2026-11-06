import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:namer_app/features/mapa/domain/entities/estaca_navegavel.dart';
import 'package:namer_app/features/mapa/domain/repositories/navegacao_estacas_repository.dart';
import 'package:namer_app/features/mapa/presentation/viewmodels/escolha_de_estaca_view_model.dart';
import 'package:namer_app/features/mapa/presentation/widgets/folha_de_navegacao.dart';

class _EstacasFalsas implements NavegacaoEstacasRepository {
  @override
  Future<List<String>> trechos() async => ['C1', 'D2'];

  @override
  Future<List<String>> kms(String trecho) async =>
      trecho == 'C1' ? ['224', '225'] : ['230'];

  @override
  Future<List<EstacaNavegavel>> estacas(String trecho, String km) async => [
        EstacaNavegavel(
          trecho: trecho,
          km: km,
          rotulo: 'EST. 10',
          numero: 10,
          ponto: const LatLng(-15.8, -47.9),
        ),
      ];
}

// Respostas que só chegam quando o teste solta (para trocar a escolha no meio).
class _EstacasLentas implements NavegacaoEstacasRepository {
  final kmsPedidos = <String, Completer<List<String>>>{};
  final estacasPedidas = <String, Completer<List<EstacaNavegavel>>>{};

  @override
  Future<List<String>> trechos() async => ['C1', 'D2'];

  @override
  Future<List<String>> kms(String trecho) =>
      (kmsPedidos[trecho] = Completer()).future;

  @override
  Future<List<EstacaNavegavel>> estacas(String trecho, String km) =>
      (estacasPedidas['$trecho|$km'] = Completer()).future;
}

EstacaNavegavel _estaca(String trecho, String km) => EstacaNavegavel(
      trecho: trecho,
      km: km,
      rotulo: 'EST. 10',
      numero: 10,
      ponto: const LatLng(-15.8, -47.9),
    );

void main() {
  group('Resposta atrasada', () {
    test('KMs do trecho anterior não entram no trecho novo', () async {
      final repositorio = _EstacasLentas();
      final vm = EscolhaDeEstacaViewModel(repositorio: repositorio);
      await vm.carregar();

      unawaited(vm.escolherTrecho('C1'));
      unawaited(vm.escolherTrecho('D2'));
      repositorio.kmsPedidos['D2']!.complete(['230']);
      await pumpEventQueue();
      repositorio.kmsPedidos['C1']!.complete(['224', '225']);
      await pumpEventQueue();

      expect(vm.trecho, 'D2');
      expect(vm.kms, ['230']);
    });

    test('estacas do KM anterior não entram no KM novo', () async {
      final repositorio = _EstacasLentas();
      final vm = EscolhaDeEstacaViewModel(repositorio: repositorio);
      await vm.carregar();
      unawaited(vm.escolherTrecho('C1'));
      repositorio.kmsPedidos['C1']!.complete(['224', '225']);
      await pumpEventQueue();

      unawaited(vm.escolherKm('224'));
      unawaited(vm.escolherKm('225'));
      repositorio.estacasPedidas['C1|225']!.complete([_estaca('C1', '225')]);
      await pumpEventQueue();
      repositorio.estacasPedidas['C1|224']!.complete([_estaca('C1', '224')]);
      await pumpEventQueue();

      expect(vm.km, '225');
      expect(vm.estacas.single.km, '225');
    });
  });

  // O builder da folha roda de novo quando ela é arrastada. A folha tem que
  // continuar no ViewModel em uso: um novo viria sem dados e giraria para
  // sempre, perdendo o trecho escolhido.
  testWidgets('arrastar a folha não troca o ViewModel nem perde a escolha',
      (tester) async {
    var montagens = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              // Como o builder antigo: um ViewModel a cada vez.
              builder: (_) {
                montagens++;
                return FolhaDeNavegacao(
                  viewModel:
                      EscolhaDeEstacaViewModel(repositorio: _EstacasFalsas()),
                );
              },
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trecho'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('C1').last);
    await tester.pumpAndSettle();
    expect(find.text('KM'), findsOneWidget);

    final antes = montagens;
    await tester.drag(find.text('Ir para uma estaca'), const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(montagens, greaterThan(antes));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('C1'), findsOneWidget);
    expect(find.text('KM'), findsOneWidget);
  });
}
