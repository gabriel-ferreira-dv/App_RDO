import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/widgets/seletor_de_dia.dart';

void main() {
  Future<List<DateTime>> montar(WidgetTester tester,
      {required DateTime dia, DateTime? hoje, bool habilitado = true}) async {
    final escolhidos = <DateTime>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SeletorDeDia(
          dia: dia,
          hoje: hoje,
          habilitado: habilitado,
          aoMudar: escolhidos.add,
        ),
      ),
    ));
    return escolhidos;
  }

  IconButton botao(WidgetTester tester, IconData icone) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icone));
  const anterior = Icons.chevron_left;
  const seguinte = Icons.chevron_right;

  testWidgets('hoje: mostra "Hoje" e não deixa passar de hoje',
      (tester) async {
    final escolhidos = await montar(tester,
        dia: DateTime(2026, 9, 24), hoje: DateTime(2026, 9, 24));
    expect(find.text('Hoje, 24/09/2026'), findsOneWidget);
    expect(botao(tester, seguinte).onPressed, isNull);

    await tester.tap(find.byIcon(anterior));
    expect(escolhidos, [DateTime(2026, 9, 23)]);
  });

  testWidgets('desabilitado (carregando): nenhum botão responde',
      (tester) async {
    await montar(tester,
        dia: DateTime(2026, 9, 22),
        hoje: DateTime(2026, 9, 24),
        habilitado: false);
    expect(find.text('22/09/2026'), findsOneWidget);
    expect(botao(tester, anterior).onPressed, isNull);
    expect(botao(tester, seguinte).onPressed, isNull);
    expect(
        tester
            .widget<TextButton>(find.byWidgetPredicate((w) => w is TextButton))
            .onPressed,
        isNull);
  });
}
