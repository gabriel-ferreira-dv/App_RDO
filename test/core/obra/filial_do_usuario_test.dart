import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/obra/config_da_obra.dart' show filialPadrao;
import 'package:namer_app/core/obra/filial_do_usuario.dart';
import 'package:namer_app/features/obra/config_da_obra_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sem nada guardado, vale a filial padrão', () async {
    SharedPreferences.setMockInitialValues({});
    final filial = FilialDoUsuario();
    await ConfigDaObraService(filial).carregarDoAparelho();
    expect(filial.codigo, filialPadrao);
  });

  test('a filial guardada no aparelho chega a quem recebeu o objeto', () async {
    SharedPreferences.setMockInitialValues({'filial_da_obra': '020300'});
    final filial = FilialDoUsuario();
    await ConfigDaObraService(filial).carregarDoAparelho();
    expect(filial.codigo, '020300');

    // Outra instância (outro teste, outro isolate) não é afetada.
    expect(FilialDoUsuario().codigo, filialPadrao);
  });
}
