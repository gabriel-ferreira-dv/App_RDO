import 'package:shared_preferences/shared_preferences.dart';

// O que fica guardado no celular: a cópia do aviso de cada filial (para usar
// sem internet) e a confirmação de leitura de cada usuário.
abstract interface class AvisoLocalDataSource {
  Future<String?> copia(String filial);
  Future<void> guardarCopia(String filial, String json);
  Future<String?> ciencia(String email, String filial);
  Future<void> guardarCiencia(String email, String filial, String valor);
}

class AvisoLocalPrefs implements AvisoLocalDataSource {
  const AvisoLocalPrefs();

  static String _chaveDaCopia(String filial) =>
      'aviso_privacidade_copia_$filial';

  // Dois usuários no mesmo celular confirmam cada um; quem muda de filial
  // confirma o aviso da nova.
  static String _chaveDaCiencia(String email, String filial) =>
      'aviso_privacidade_${filial}_${email.trim().toLowerCase()}';

  @override
  Future<String?> copia(String filial) async =>
      (await SharedPreferences.getInstance()).getString(_chaveDaCopia(filial));

  @override
  Future<void> guardarCopia(String filial, String json) async =>
      (await SharedPreferences.getInstance())
          .setString(_chaveDaCopia(filial), json);

  @override
  Future<String?> ciencia(String email, String filial) async =>
      (await SharedPreferences.getInstance())
          .getString(_chaveDaCiencia(email, filial));

  @override
  Future<void> guardarCiencia(
          String email, String filial, String valor) async =>
      (await SharedPreferences.getInstance())
          .setString(_chaveDaCiencia(email, filial), valor);
}
