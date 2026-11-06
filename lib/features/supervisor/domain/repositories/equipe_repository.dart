import '../entities/encarregado_da_equipe.dart';

// A equipe do supervisor, guardada no servidor (vale em qualquer celular e
// as regras de acesso do banco usam ela).
abstract interface class EquipeRepository {
  // Equipe do supervisor; vazio sem matrícula ou sem internet.
  Future<List<EncarregadoDaEquipe>> equipeDe(String supervisorMatricula);

  // Troca a equipe pela lista escolhida. null = salvou; senão, o erro.
  Future<String?> salvarEquipe(
      String supervisorMatricula, List<EncarregadoDaEquipe> equipe);

  // Encarregados com apontamento nos últimos dias, para montar a equipe.
  Future<List<EncarregadoDaEquipe>> encarregadosRecentes();
}
