import 'dart:math';

// Se [km] está entre [kmDe] e [kmAte], inclusive e em qualquer ordem. KM que
// não é número só casa com as pontas.
bool kmNoIntervalo(String km, String kmDe, String kmAte) {
  final n = int.tryParse(km.trim());
  final de = int.tryParse(kmDe.trim());
  final ate = int.tryParse(kmAte.trim());
  if (n == null || de == null || ate == null) return km == kmDe || km == kmAte;
  return n >= min(de, ate) && n <= max(de, ate);
}

// Quantos KMs de cada lado entram nas listas de estaca, para o serviço poder
// atravessar o KM.
const int kmsVizinhos = 2;

// Uma estaca do projeto: número, KM a que pertence e, em pista dupla, a via.
class EstacaDoProjeto {
  final String trecho;
  final int numero;

  // Como a estaca é escrita nas planilhas ("1115", "57").
  final String rotulo;
  final String km;

  // null em trecho de pista simples, onde a numeração não indica sentido.
  final String? via;

  // true quando o KM veio da estaca gêmea da outra pista.
  final bool kmDerivado;

  const EstacaDoProjeto({
    required this.trecho,
    required this.numero,
    required this.rotulo,
    required this.km,
    required this.via,
    this.kmDerivado = false,
  });
}

// Rótulo na lista da estaca final: com o KM ao lado quando é de outro KM.
// Sem KM (obra ou trecho que não usa), só o rótulo.
String rotuloComKm(EstacaDoProjeto estaca, String kmSelecionado,
        {bool usaKm = true}) =>
    !usaKm || estaca.km.isEmpty || estaca.km == kmSelecionado
        ? estaca.rotulo
        : '${estaca.rotulo} (KM ${estaca.km})';
