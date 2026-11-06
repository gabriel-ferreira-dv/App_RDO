import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/registro/domain/regras/textos_do_registro.dart';

void main() {
  test('o local junta trecho e KM; sem KM, só o trecho', () {
    expect(textoDoLocal('C1', '225', ''), 'C1 / KM 225');
    expect(textoDoLocal('C1', '225', '226'), 'C1 / KM 225 a 226');
    expect(textoDoLocal('PÁTIO DE VIGAS', '', ''), 'PÁTIO DE VIGAS');
  });

  test('estaca final vazia ou igual é uma estaca só', () {
    expect(textoDasEstacas('EST. 1115', 'EST. 1120'), 'EST. 1115 a EST. 1120');
    expect(textoDasEstacas('EST. 1115', 'EST. 1115'), 'EST. 1115');
    // Antes saía "EST. 1115 a " no PDF.
    expect(textoDasEstacas('EST. 1115', ''), 'EST. 1115');
    expect(textoDasEstacas('', ''), '');
  });

  test('medição só com quantidade e unidade', () {
    expect(textoDaMedicao(1850, 'm³'), '1850 m³');
    expect(textoDaMedicao(120.5, 'm²'), '120,5 m²');
    expect(textoDaMedicao(null, 'm³'), '');
    expect(textoDaMedicao(10, ''), '');
  });
}
