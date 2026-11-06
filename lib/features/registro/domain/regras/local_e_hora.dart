import '../../../../core/extensions/data_hora_extensions.dart';

// Linha "onde e quando" de um registro, igual no Histórico e no Admin:
// "C1 · est. 2245 – 2247 · 14:12"; sem estaca, o KM: "C1 · km 225 · 14:12".
String localEHoraDoRegistro({
  required String trecho,
  required String estacaInicial,
  required String estacaFinal,
  required String km,
  required DateTime momento,
}) =>
    [
      trecho,
      if (estacaInicial.isNotEmpty)
        estacaFinal.isEmpty || estacaFinal == estacaInicial
            ? 'est. $estacaInicial'
            : 'est. $estacaInicial – $estacaFinal'
      else if (km.isNotEmpty)
        'km $km',
      momento.horaCurta,
    ].join(' · ');
