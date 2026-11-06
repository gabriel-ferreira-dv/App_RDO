import 'config_da_obra.dart' show filialPadrao;

// Filial do usuário logado (perfis_app.filial_id): decide a config da obra,
// a pasta das fotos no bucket, os dados do projeto e o aviso de privacidade.
//
// Uma instância por isolate, criada em app/dependencias.dart e passada pelo
// construtor a quem precisa. Quem grava é o ConfigDaObraService (do aparelho
// ao abrir, do servidor depois do login).
class FilialDoUsuario {
  FilialDoUsuario([this._codigo = filialPadrao]);

  String _codigo;

  String get codigo => _codigo;

  void definir(String codigo) => _codigo = codigo;
}
