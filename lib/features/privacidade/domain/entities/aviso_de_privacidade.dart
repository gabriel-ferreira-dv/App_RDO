import 'linha_do_aviso.dart';

// Aviso de privacidade de uma filial (LGPD, art. 9º). O texto é editado no
// Supabase; "# " no começo da linha marca um título.
class AvisoDePrivacidade {
  // Filial dona do aviso (perfis_app.filial_id).
  final String filial;

  // Sobe quando os usuários da filial devem confirmar a leitura de novo.
  final int versao;
  final String texto;
  final DateTime? atualizadoEm;

  const AvisoDePrivacidade({
    required this.filial,
    required this.versao,
    required this.texto,
    this.atualizadoEm,
  });

  List<LinhaDoAviso> get linhas => linhasDoAviso(texto);
}
