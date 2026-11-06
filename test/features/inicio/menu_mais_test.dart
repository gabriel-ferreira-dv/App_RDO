import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/theme/app_theme.dart';
import 'package:namer_app/features/inicio/presentation/widgets/menu_mais.dart';

void main() {
  // Telas em pixels lógicos: um celular pequeno e um como o do emulador.
  for (final tela in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets(
        'com todas as opções cabe sem estourar e chega em Privacidade '
        '(${tela.width.toInt()}x${tela.height.toInt()})', (tester) async {
      tester.view.physicalSize = tela * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      OpcaoDoMais? escolhida;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => escolhida = await mostrarMenuMais(
                  context,
                  paradoAgora: true,
                  ehSupervisor: true,
                  ehAdmin: true,
                ),
                child: const Text('Mais'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Mais'));
      await tester.pumpAndSettle();

      // Um estouro (faixa amarela e preta) faria o teste falhar aqui.
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('Privacidade'), 100,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Privacidade'));
      await tester.pumpAndSettle();

      expect(escolhida, OpcaoDoMais.privacidade);
    });
  }
}
