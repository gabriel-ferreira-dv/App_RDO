import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/extensions/data_hora_extensions.dart';
import 'package:namer_app/core/extensions/hora_do_dia_extensions.dart';

void main() {
  final d = DateTime(2026, 3, 7, 8, 5);

  test('data e hora com dois dígitos', () {
    expect(d.dataCurta, '07/03/2026');
    expect(d.diaEMes, '07/03');
    expect(d.horaCurta, '08:05');
  });

  test('formatos para consulta e nome de arquivo', () {
    expect(d.dataIso, '2026-03-07');
    expect(d.dataCompacta, '20260307');
    expect(DateTime(987, 1, 2).dataIso, '0987-01-02');
  });

  test('só o dia, sem a hora', () {
    expect(d.soDia, DateTime(2026, 3, 7));
    expect(d.soDia == DateTime(2026, 3, 7, 23, 59).soDia, isTrue);
  });

  test('hora do relógio do Flutter', () {
    expect(const TimeOfDay(hour: 7, minute: 3).horaCurta, '07:03');
  });
}
