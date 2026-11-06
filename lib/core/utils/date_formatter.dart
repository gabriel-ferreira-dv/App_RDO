import '../extensions/data_hora_extensions.dart';

// Datas ISO em UTC (como no banco) para exibir no horário local.

// dd/mm/aaaa local; devolve [iso] se não for válido.
String formatarData(String iso) =>
    DateTime.tryParse(iso)?.toLocal().dataCurta ?? iso;

// "dd/mm/aaaa às hh:mm" local; devolve [iso] se não for válido.
String formatarDataHora(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  return d == null ? iso : '${d.dataCurta} às ${d.horaCurta}';
}

// Dia local (sem hora) de um ISO em UTC, comparável com ==; null se inválido.
DateTime? diaLocalDe(String iso) => DateTime.tryParse(iso)?.toLocal().soDia;

// hh:mm local; vazio se [iso] não for válido.
String formatarHora(String iso) =>
    DateTime.tryParse(iso)?.toLocal().horaCurta ?? '';
