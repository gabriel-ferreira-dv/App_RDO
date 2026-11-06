// Um encarregado que faz parte da equipe de um supervisor.
class EncarregadoDaEquipe {
  final String matricula;
  final String nome;

  const EncarregadoDaEquipe({required this.matricula, required this.nome});

  @override
  bool operator ==(Object other) =>
      other is EncarregadoDaEquipe && other.matricula == matricula;

  @override
  int get hashCode => matricula.hashCode;
}
