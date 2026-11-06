import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/obra/dia_de_trabalho.dart';

void main() {
  test('a busca do dia vai da meia-noite à virada do dia seguinte', () {
    final janela = janelaDoDiaDeTrabalho(DateTime(2026, 9, 24, 15));
    expect(janela.de, DateTime(2026, 9, 24).toUtc());
    expect(janela.ate, DateTime(2026, 9, 25, horaViradaTurnoNoturno).toUtc());
  });

  test('a madrugada só conta no dia anterior para quem é da noite', () {
    final madrugada = DateTime(2026, 9, 25, 2);
    expect(ehDoDiaDeTrabalho(madrugada, DateTime(2026, 9, 24), noturno: true),
        isTrue);
    expect(ehDoDiaDeTrabalho(madrugada, DateTime(2026, 9, 24), noturno: false),
        isFalse);
  });

  test('separa por matrícula o que é do dia de cada um', () {
    final itens = [
      ('ana', DateTime(2026, 9, 24, 9)),
      ('ana', DateTime(2026, 9, 25, 2)),
      ('joao', DateTime(2026, 9, 25, 2)),
    ];
    final porMatricula = porMatriculaNoDia(itens,
        dia: DateTime(2026, 9, 24),
        matricula: (i) => i.$1,
        quando: (i) => i.$2,
        ehNoturno: (m) => m == 'joao');
    // A da Ana às 2h é do dia 25 (ela é do dia); a do João, da noite do 24.
    expect(porMatricula['ana'], [itens[0]]);
    expect(porMatricula['joao'], [itens[2]]);
  });

  test('o hoje do relógio segue o turno, lido a cada vez', () {
    var noturno = false;
    final relogio = RelogioDoTurno(
        agora: () => DateTime(2026, 9, 25, 2), noturno: () => noturno);
    expect(relogio.hoje, DateTime(2026, 9, 25));
    noturno = true;
    expect(relogio.hoje, DateTime(2026, 9, 24));
  });
}
