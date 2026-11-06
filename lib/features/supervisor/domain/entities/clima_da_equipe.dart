// Clima que o encarregado informou no RDO do dia.
class ClimaDaEquipe {
  final String manha;
  final String tarde;
  final String noite;

  const ClimaDaEquipe({this.manha = '', this.tarde = '', this.noite = ''});

  // "Manhã: Bom  Tarde: Chuvoso"; vazio se nada foi informado.
  String get linha => [
        if (manha.isNotEmpty) 'Manhã: $manha',
        if (tarde.isNotEmpty) 'Tarde: $tarde',
        if (noite.isNotEmpty) 'Noite: $noite',
      ].join('  ');
}
