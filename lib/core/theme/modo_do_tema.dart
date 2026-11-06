import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModoDoTema {
  ModoDoTema._interno();
  static final ModoDoTema instancia = ModoDoTema._interno();

  static const _chave = 'modo_do_tema';

  final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.system);

  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      modo.value = switch (prefs.getString(_chave)) {
        'claro' => ThemeMode.light,
        'escuro' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (e) {
      debugPrint("Modo do tema: falha ao ler do aparelho: $e");
    }
  }

  Future<void> alternar(Brightness naTela) async {
    final paraEscuro = naTela == Brightness.light;
    modo.value = paraEscuro ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, paraEscuro ? 'escuro' : 'claro');
    } catch (e) {
      debugPrint('Modo do tema: falha ao guardar: $e');
    }
  }
}
