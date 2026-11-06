// Dia de trabalho de quem é do turno da noite: até esta hora, ainda está no
// dia anterior (o turno das 17h às 2h fica inteiro no dia em que começou).
const int horaViradaTurnoNoturno = 12;

// Dia de trabalho a que [momento] (hora local) pertence.
DateTime diaDoTurno(DateTime momento, {required bool noturno}) {
  final dia = DateTime(momento.year, momento.month, momento.day);
  return noturno && momento.hour < horaViradaTurnoNoturno
      ? DateTime(dia.year, dia.month, dia.day - 1)
      : dia;
}

// Se [momento] é do [dia] de trabalho de quem fez.
bool ehDoDiaDeTrabalho(DateTime momento, DateTime dia, {required bool noturno}) =>
    diaDoTurno(momento, noturno: noturno) ==
    DateTime(dia.year, dia.month, dia.day);

// O que buscar para um dia de trabalho: da meia-noite até a virada do dia
// seguinte (a madrugada de quem é da noite entra), em UTC. Cada item é
// conferido depois com [ehDoDiaDeTrabalho] ou [porMatriculaNoDia].
({DateTime de, DateTime ate}) janelaDoDiaDeTrabalho(DateTime dia) => (
      de: DateTime(dia.year, dia.month, dia.day).toUtc(),
      ate: DateTime(dia.year, dia.month, dia.day + 1, horaViradaTurnoNoturno)
          .toUtc(),
    );

// Separa por matrícula o que é do [dia] de trabalho de cada um.
Map<String, List<T>> porMatriculaNoDia<T>(
  Iterable<T> itens, {
  required DateTime dia,
  required String Function(T item) matricula,
  required DateTime Function(T item) quando,
  required bool Function(String matricula) ehNoturno,
}) {
  final porMatricula = <String, List<T>>{};
  for (final item in itens) {
    final dono = matricula(item);
    if (!ehDoDiaDeTrabalho(quando(item), dia, noturno: ehNoturno(dono))) continue;
    porMatricula.putIfAbsent(dono, () => []).add(item);
  }
  return porMatricula;
}

// O "hoje" de trabalho de quem usa o app: o relógio levado para o dia do
// turno. O turno é lido a cada uso, porque a lista do turno da noite pode
// chegar do servidor com a tela já aberta.
class RelogioDoTurno {
  final DateTime Function() agora;
  final bool Function() noturno;

  const RelogioDoTurno({this.agora = DateTime.now, this.noturno = _diurno});

  static bool _diurno() => false;

  DateTime get hoje => diaDoTurno(agora(), noturno: noturno());
}
