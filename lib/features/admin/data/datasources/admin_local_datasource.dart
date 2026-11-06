import 'package:shared_preferences/shared_preferences.dart';

// A última resposta do servidor sobre "sou admin?", para usar sem internet.
abstract interface class AdminLocalDataSource {
  Future<bool?> souAdmin();
  Future<void> guardarSouAdmin(bool admin);
}

class AdminLocalPrefs implements AdminLocalDataSource {
  const AdminLocalPrefs();

  static const _chave = 'sou_admin_painel';

  @override
  Future<bool?> souAdmin() async =>
      (await SharedPreferences.getInstance()).getBool(_chave);

  @override
  Future<void> guardarSouAdmin(bool admin) async =>
      (await SharedPreferences.getInstance()).setBool(_chave, admin);
}
