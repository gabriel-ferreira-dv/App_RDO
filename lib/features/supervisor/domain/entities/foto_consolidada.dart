import 'dart:typed_data';

// Uma foto que vai para o relatório da equipe, ainda no servidor.
class FotoParaBaixar {
  // Posição do encarregado na lista do dia.
  final int encarregado;
  final String caminho;
  final String legenda;

  const FotoParaBaixar({
    required this.encarregado,
    required this.caminho,
    required this.legenda,
  });
}

// Uma foto já baixada, pronta para entrar no PDF.
class FotoConsolidada {
  final Uint8List bytes;
  final String legenda;

  const FotoConsolidada({required this.bytes, required this.legenda});
}
