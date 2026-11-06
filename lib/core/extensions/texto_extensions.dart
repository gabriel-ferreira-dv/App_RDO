// Texto comparável e contagens no formato das telas
extension TextoBr on String {

  String get semAcento {
    const com = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const sem = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
    final saida = StringBuffer();
    for (final rune in replaceAll(RegExp('[̀-ͯ]'), '').runes) {
      final letra = String.fromCharCode(rune);
      final i = com.indexOf(letra);
      saida.write(i < 0 ? letra : sem[i]);
    }
    return saida.toString();
  }
}

extension QuantidadeBr on int {
  // "1 registro", "3 registros" isso fica la no historico
  String plural(String singular, String varios) =>
      '$this ${this == 1 ? singular : varios}';
}
