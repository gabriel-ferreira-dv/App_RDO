import '../../../../core/extensions/texto_extensions.dart';
import '../../../supervisor/domain/entities/registro_da_equipe.dart';

// Os registros de um usuário no dia.
class RegistrosDoUsuario {
  final String nome;
  final String matricula;
  final List<RegistroDaEquipe> registros;

  const RegistrosDoUsuario(this.nome, this.matricula, this.registros);
}

// Agrupa por usuário, em ordem alfabética, e filtra pelo nome ou matrícula
// ([busca] sem diferença de maiúsculas e acentos).
List<RegistrosDoUsuario> agruparPorUsuario(
  List<RegistroDaEquipe> registros, {
  String busca = '',
}) {
  String comparavel(String texto) => texto.toLowerCase().semAcento;
  final termo = comparavel(busca.trim());
  final porMatricula = <String, List<RegistroDaEquipe>>{};
  for (final r in registros) {
    final chave =
        r.usuarioMatricula.isEmpty ? r.usuarioNome : r.usuarioMatricula;
    porMatricula.putIfAbsent(chave, () => []).add(r);
  }
  return [
    for (final lista in porMatricula.values)
      RegistrosDoUsuario(
          lista.first.usuarioNome, lista.first.usuarioMatricula, lista),
  ]
      .where((g) =>
          termo.isEmpty ||
          comparavel(g.nome).contains(termo) ||
          g.matricula.contains(termo))
      .toList()
    ..sort((a, b) => comparavel(a.nome).compareTo(comparavel(b.nome)));
}
