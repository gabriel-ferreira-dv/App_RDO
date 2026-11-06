import 'estaca_do_projeto.dart';

// As estacas de uma lista de escolha (estaca inicial ou final): como cada uma
// aparece e qual estaca é cada item. Estaca de outro KM aparece com o KM ao
// lado; sem KM (obra ou trecho que não usa), só o rótulo.
class ListaDeEstacas {
  final List<EstacaDoProjeto> estacas;

  // KM escolhido no formulário.
  final String km;
  final bool usaKm;

  const ListaDeEstacas(this.estacas, {this.km = '', this.usaKm = true});

  String rotuloNaLista(EstacaDoProjeto estaca) =>
      rotuloComKm(estaca, km, usaKm: usaKm);

  List<String> get rotulos => [for (final e in estacas) rotuloNaLista(e)];

  EstacaDoProjeto? porRotulo(String? rotulo) {
    if (rotulo == null) return null;
    for (final estaca in estacas) {
      if (estaca.rotulo == rotulo) return estaca;
    }
    return null;
  }

  // Como a estaca [rotulo] aparece no campo.
  String? rotuloNoCampo(String? rotulo) {
    final estaca = porRotulo(rotulo);
    return estaca == null ? rotulo : rotuloNaLista(estaca);
  }

  // Rótulo da estaca escolhida na lista, sem o KM ao lado.
  String rotuloEscolhido(String item) {
    for (final estaca in estacas) {
      if (rotuloNaLista(estaca) == item) return estaca.rotulo;
    }
    return item;
  }

  // Posição da estaca [rotulo] na lista; null se não está nela.
  int? indiceDe(String? rotulo) {
    final i = estacas.indexWhere((e) => e.rotulo == rotulo);
    return i < 0 ? null : i;
  }

  // Posição da primeira estaca do KM escolhido, onde a lista abre.
  int? get indiceDoKm {
    if (!usaKm) return null;
    final i = estacas.indexWhere((e) => e.km == km);
    return i < 0 ? null : i;
  }
}
