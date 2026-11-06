import '../entities/grupo_atividade.dart' show formatarQuantidade;
import 'vias_estaqueamento.dart' show textoDoKm;

// Os pedaços de texto de um registro, iguais em todas as telas e relatórios.

// "C1 / KM 225" ou "C1 / KM 225 a 226"; sem KM, só o trecho.
String textoDoLocal(String trecho, String km, String kmFinal) =>
    [trecho, textoDoKm(km, kmFinal)].where((t) => t.isNotEmpty).join(' / ');

// "EST. 1115" ou "EST. 1115 a EST. 1120". Final vazia ou igual à inicial é
// uma estaca só; sem estaca, vazio.
String textoDasEstacas(String inicial, String fim) {
  if (inicial.isEmpty) return fim;
  return fim.isEmpty || fim == inicial ? inicial : '$inicial a $fim';
}

// "1850 m³"; vazio sem medição.
String textoDaMedicao(double? quantidade, String unidade) =>
    quantidade == null || unidade.isEmpty
        ? ''
        : '${formatarQuantidade(quantidade)} $unidade';
