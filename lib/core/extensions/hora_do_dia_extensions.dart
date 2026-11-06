import 'package:flutter/material.dart';

// Hora escolhida no relógio do Flutter, no formato das telas.
extension HoraDoDiaBr on TimeOfDay {
  // 08:05
  String get horaCurta =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
