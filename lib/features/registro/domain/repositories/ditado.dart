// Ditado por voz da descrição do registro.
abstract interface class Ditado {
  // false quando o aparelho não tem reconhecimento de voz.
  Future<bool> iniciar();

  // [aoReconhecer] recebe o texto ditado até agora; [aoTerminar], quando a
  // frase acaba.
  Future<void> ouvir({
    required void Function(String texto) aoReconhecer,
    void Function()? aoTerminar,
  });

  Future<void> parar();

  void cancelar();
}
