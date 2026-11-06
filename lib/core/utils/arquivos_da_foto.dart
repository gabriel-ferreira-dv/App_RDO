import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Arquivos de uma foto de registro: a carimbada (a que o app mostra, põe no
// PDF e compartilha), a original sem carimbo e o minimapa da hora da foto.
// O carimbo é refeito a partir das duas últimas quando o registro é editado.
class ArquivosDaFoto {
  final String carimbada;
  final String original;
  final String minimapa;

  const ArquivosDaFoto(this.carimbada, this.original, this.minimapa);

  // Caminhos da foto [nome] dentro de documentos/fotos, criando as pastas.
  static Future<ArquivosDaFoto> para(String nome) async {
    final docs = await getApplicationDocumentsDirectory();
    return dentroDe(p.join(docs.path, 'fotos'), nome);
  }

  static ArquivosDaFoto dentroDe(String pastaFotos, String nome) {
    for (final pasta in [
      pastaFotos,
      p.join(pastaFotos, 'originais'),
      p.join(pastaFotos, 'minimapas')
    ]) {
      Directory(pasta).createSync(recursive: true);
    }
    return ArquivosDaFoto(
      p.join(pastaFotos, nome),
      p.join(pastaFotos, 'originais', nome),
      p.join(
          pastaFotos, 'minimapas', '${p.basenameWithoutExtension(nome)}.png'),
    );
  }
}

// Original sem carimbo da foto [carimbada], se ela foi guardada (fotos de
// registro tiradas a partir desta versão); null nas antigas.
String? originalDaFoto(String carimbada) {
  final original =
      p.join(p.dirname(carimbada), 'originais', p.basename(carimbada));
  return File(original).existsSync() ? original : null;
}
