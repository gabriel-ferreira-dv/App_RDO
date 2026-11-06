// Datas e horas nos formatos usados no app (telas, PDF, nomes de arquivo e consultas ao servidor)
extension DataHoraBr on DateTime {
  // 22/10/2026
  String get dataCurta => '$diaEMes/$year';

  // 22/10
  String get diaEMes => '${_dois(day)}/${_dois(month)}';

  // 08:05
  String get horaCurta => '${_dois(hour)}:${_dois(minute)}';

  // 2026-10-22 (consultas e chaves)
  String get dataIso => '${year.toString().padLeft(4, '0')}-'
      '${_dois(month)}-${_dois(day)}';

  // 20261022 (nomes de arquivo)
  String get dataCompacta => dataIso.replaceAll('-', '');

  // Só o dia, sem a hora (comparável com ==).
  DateTime get soDia => DateTime(year, month, day);
}

String _dois(int n) => n.toString().padLeft(2, '0');
