// Foto de uma paralisação, guardada no aparelho.
class FotoDaParalisacao {
  final int id;
  final String caminhoArquivo;
  final String criadoEm;

  const FotoDaParalisacao({
    required this.id,
    required this.caminhoArquivo,
    required this.criadoEm,
  });
}

// Trecho e KM sugeridos para uma paralisação nova.
typedef LocalDaParada = ({String trecho, String km});
