import '../../../../core/extensions/data_hora_extensions.dart';
import '../entities/registro_da_equipe.dart';

// Um registro numa linha, no mesmo formato do RDO individual. O texto é o
// mesmo no cartão e no PDF; quem limpa o que a fonte do PDF não desenha é o
// próprio PDF (ver blocoDoEncarregado).
String descreverAtividade(RegistroDaEquipe r) {
  final passo = r.servicoNotavelDetalhe.trim();
  final via = r.via.trim();
  // Marca o que foi lançado pela supervisão.
  final porOutro = r.registradoPorNome.trim();
  return '${r.servicoNotavel}${passo.isNotEmpty ? ' ($passo)' : ''}, '
      '${r.local}'
      '${r.estacas.isNotEmpty ? ', estaca ${r.estacas}' : ''}'
      '${via.isNotEmpty ? ', via $via' : ''}'
      '${r.medicao.isNotEmpty ? ' - ${r.medicao}' : ''}'
      '${porOutro.isNotEmpty ? ' (lançado por $porOutro)' : ''}.';
}

// Uma linha por atividade, na ordem do dia. Lançamentos que dariam a mesma
// linha viram um só, com o horário "13:15 a 15:23".
List<String> listarAtividades(List<RegistroDaEquipe> registros) {
  // O próprio texto é a chave.
  final horasPorLinha = <String, List<DateTime>>{};
  for (final r in registros) {
    horasPorLinha.putIfAbsent(descreverAtividade(r), () => []).add(r.criadoEm);
  }
  return [
    for (final e in horasPorLinha.entries) '${_intervalo(e.value)}  ${e.key}',
  ];
}

String _intervalo(List<DateTime> horas) {
  final ordenadas = [...horas]..sort();
  final inicio = ordenadas.first.horaCurta;
  final fim = ordenadas.last.horaCurta;
  return inicio == fim ? inicio : '$inicio a $fim';
}
