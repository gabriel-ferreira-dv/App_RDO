// Uma linha do texto do aviso, já classificada.
class LinhaDoAviso {
  final String texto;

  // A linha começava com "#" no Supabase.
  final bool ehTitulo;

  const LinhaDoAviso(this.texto, {this.ehTitulo = false});

  // Separador entre parágrafos.
  bool get vazia => texto.isEmpty;
}

// Quebra o texto em linhas: "# Título" vira título; várias linhas em branco
// seguidas viram uma só; as do começo e do fim saem.
List<LinhaDoAviso> linhasDoAviso(String texto) {
  final linhas = <LinhaDoAviso>[];
  for (final bruta in texto.replaceAll('\r', '').split('\n')) {
    final linha = bruta.trim();
    if (linha.startsWith('#')) {
      final titulo = linha.replaceFirst(RegExp(r'^#+\s*'), '');
      if (titulo.isNotEmpty) linhas.add(LinhaDoAviso(titulo, ehTitulo: true));
    } else if (linha.isNotEmpty) {
      linhas.add(LinhaDoAviso(linha));
    } else if (linhas.isNotEmpty && !linhas.last.vazia) {
      linhas.add(const LinhaDoAviso(''));
    }
  }
  if (linhas.isNotEmpty && linhas.last.vazia) linhas.removeLast();
  return linhas;
}
