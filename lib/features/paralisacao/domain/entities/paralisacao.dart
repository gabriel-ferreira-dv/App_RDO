import '../../../../core/extensions/data_hora_extensions.dart';
import '../../../../core/obra/dia_de_trabalho.dart';

// Motivos oferecidos no formulário, dos mais comuns aos raros.
const List<String> motivosParalisacao = [
  'Chuva',
  'Terreno encharcado',
  'Falta de material',
  'Equipamento quebrado',
  'Falta de equipamento',
  'Interferência',
  'Aguardando liberação',
  'Segurança',
  'Outro',
];

// Uma parada do serviço. [fim] nulo = ainda parado.
class Paralisacao {
  final int? id;
  final int usuarioId;
  final String motivo;
  final String observacao;
  final String trecho;
  final String km;
  final DateTime inicio; // UTC
  final DateTime? fim; // UTC
  final String criadoEm;

  const Paralisacao({
    this.id,
    required this.usuarioId,
    required this.motivo,
    this.observacao = '',
    this.trecho = '',
    this.km = '',
    required this.inicio,
    this.fim,
    required this.criadoEm,
  });

  bool get emAndamento => fim == null;

  // Dia de trabalho a que pertence (no turno da noite, vai até o meio-dia).
  DateTime diaDeTrabalho({required bool noturno}) =>
      diaDoTurno(inicio.toLocal(), noturno: noturno);

  // Linha para lista e relatório (ver [descreverParalisacao]).
  String get descricao => descreverParalisacao(
        inicio: inicio.toLocal(),
        fim: fim?.toLocal(),
        motivo: motivo,
        trecho: trecho,
        km: km,
        observacao: observacao,
      );

  // "C1 / KM 225 · alagou a pista" (vazio sem local nem observação).
  String get localEObservacao => [
        if (trecho.isNotEmpty) km.isEmpty ? trecho : '$trecho / KM $km',
        if (observacao.isNotEmpty) observacao,
      ].join(' · ');
}

// Problema que impede salvar a paralisação; null quando está tudo certo.
String? problemaDaParalisacao({
  required String? motivo,
  required DateTime inicio,
  DateTime? fim,
}) {
  if (motivo == null || motivo.trim().isEmpty) {
    return 'Escolha o motivo da paralisação';
  }
  if (fim != null && !fim.isAfter(inicio)) {
    return 'O término tem que ser depois do início';
  }
  return null;
}

// "2h30", "2h", "45 min".
String formatarDuracao(Duration duracao) {
  final minutos = duracao.inMinutes;
  if (minutos < 60) return '$minutos min';
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  return resto == 0
      ? '${horas}h'
      : '${horas}h${resto.toString().padLeft(2, '0')}';
}

// "13:10 às 15:40 (2h30) - Chuva - C1 / KM 225 - alagou a pista". Sem
// término: "13:10 - sem término - Chuva". Horas locais. Só hífen: a fonte do
// PDF não tem travessão.
String descreverParalisacao({
  required DateTime inicio,
  DateTime? fim,
  required String motivo,
  String trecho = '',
  String km = '',
  String observacao = '',
}) {
  final horario = fim == null
      ? '${inicio.horaCurta} - sem término'
      : '${inicio.horaCurta} às ${fim.horaCurta} '
          '(${formatarDuracao(fim.difference(inicio))})';
  final local = [
    if (trecho.trim().isNotEmpty) trecho.trim(),
    if (km.trim().isNotEmpty) 'KM ${km.trim()}',
  ].join(' / ');
  return [
    horario,
    motivo,
    if (local.isNotEmpty) local,
    if (observacao.trim().isNotEmpty) observacao.trim(),
  ].join(' - ');
}

// Tempo parado somando só as paralisações encerradas.
Duration tempoParado(Iterable<({DateTime inicio, DateTime? fim})> paradas) =>
    paradas.fold(Duration.zero, (soma, p) {
      final fim = p.fim;
      return fim == null ? soma : soma + fim.difference(p.inicio);
    });
