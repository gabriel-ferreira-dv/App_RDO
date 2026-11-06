import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/obra/config_da_obra.dart';
import 'package:namer_app/features/mapa/data/datasources/mapas_do_projeto.dart';
import 'package:namer_app/features/mapa/presentation/widgets/camada_do_projeto.dart';

// O primeiro mapa da obra, cortado em outra grade.
GradeDoMapa _grade(int linhas, int colunas) {
  final base = configPadrao.mapas.first;
  return GradeDoMapa(MapaInfo(
    base.nome,
    base.rotulo,
    swE: base.swE,
    swN: base.swN,
    neE: base.neE,
    neN: base.neN,
    linhas: linhas,
    colunas: colunas,
  ));
}

void main() {
  // A lista de mapas visíveis muda (grupos ou obra sincronizados) e a mesma
  // camada passa a desenhar outra grade, menor: as peças guardadas da grade
  // anterior não podem ser usadas nela (dava RangeError).
  testWidgets('trocar a grade da camada não usa as peças da anterior',
      (tester) async {
    final grande = _grade(20, 20);
    final pequena = _grade(2, 2);
    final atual = ValueNotifier(grande);
    addTearDown(atual.dispose);

    await tester.pumpWidget(MaterialApp(
      home: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(bounds: grande.envelope),
        ),
        children: [
          ValueListenableBuilder(
            valueListenable: atual,
            builder: (_, grade, __) => CamadaDoProjeto(grade, zoomMinimo: 0),
          ),
        ],
      ),
    ));
    await tester.pump();

    List<BaseOverlayImage> pecas() => tester
        .widget<OverlayImageLayer>(find.byType(OverlayImageLayer))
        .overlayImages;
    expect(pecas().length, greaterThan(4));

    atual.value = pequena;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(pecas(), hasLength(4));
  });
}
