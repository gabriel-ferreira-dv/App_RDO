import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/extensions/texto_extensions.dart';

void main() {
  test('tira acentos e mantém maiúsculas e minúsculas', () {
    expect('Contorno de Fundão'.semAcento, 'Contorno de Fundao');
    expect('IBIRAÇU'.semAcento, 'IBIRACU');
    expect('Ítalo, Zé e Muñoz'.semAcento, 'Italo, Ze e Munoz');
  });

  test('tira o acento que veio separado da letra', () {
    // "ç" escrito como c + cedilha (U+0327).
    expect('Ibiraçu'.semAcento, 'Ibiracu');
  });

  test('plural das contagens', () {
    expect(1.plural('registro', 'registros'), '1 registro');
    expect(0.plural('registro', 'registros'), '0 registros');
    expect(3.plural('usuário', 'usuários'), '3 usuários');
  });
}
