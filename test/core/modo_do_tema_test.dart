import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/theme/modo_do_tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tema = ModoDoTema.instancia;

  test('sem escolha guardada, segue o celular', () async {
    SharedPreferences.setMockInitialValues({});
    await tema.carregar();
    expect(tema.modo.value, ThemeMode.system);
  });

  test('o botão troca para o contrário do que está na tela e guarda', () async {
    SharedPreferences.setMockInitialValues({});
    await tema.carregar();

    await tema.alternar(Brightness.light);
    expect(tema.modo.value, ThemeMode.dark);

    // Na próxima abertura, volta escuro.
    tema.modo.value = ThemeMode.system;
    await tema.carregar();
    expect(tema.modo.value, ThemeMode.dark);

    await tema.alternar(Brightness.dark);
    expect(tema.modo.value, ThemeMode.light);
    await tema.carregar();
    expect(tema.modo.value, ThemeMode.light);
  });
}
