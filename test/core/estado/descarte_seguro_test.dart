import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/estado/descarte_seguro.dart';

class _Contador extends ChangeNotifier with DescarteSeguro {
  int valor = 0;

  void somar() => mudar(() => valor++);
}

void main() {
  test('antes do descarte: muda e avisa', () {
    final contador = _Contador();
    var avisos = 0;
    contador.addListener(() => avisos++);
    contador.somar();
    expect(contador.valor, 1);
    expect(avisos, 1);
  });

  // Uma busca que termina depois de a tela fechar não pode dar erro.
  test('depois do descarte: ignora, sem erro', () {
    final contador = _Contador()..dispose();
    expect(contador.descartado, isTrue);
    contador.somar();
    expect(contador.valor, 0);
  });
}
