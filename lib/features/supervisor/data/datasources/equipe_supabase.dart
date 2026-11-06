import 'package:supabase_flutter/supabase_flutter.dart';

// Equipe do supervisor no servidor. Lança erro sem internet.
abstract interface class EquipeRemota {
  Future<List<Map<String, dynamic>>> equipeDe(String supervisorMatricula);
  Future<void> trocarEquipe(
      String supervisorMatricula, List<Map<String, String>> encarregados);
}

// Na tabela equipes_supervisor.
class EquipeSupabase implements EquipeRemota {
  const EquipeSupabase();

  static const String tabela = 'equipes_supervisor';

  SupabaseClient get _cliente => Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> equipeDe(String supervisorMatricula) =>
      _cliente
          .from(tabela)
          .select('encarregado_matricula, encarregado_nome')
          .eq('supervisor_matricula', supervisorMatricula)
          .order('encarregado_nome', ascending: true); // o padrão é Z→A

  // Grava a equipe nova e só depois tira quem saiu: se a segunda parte
  // falhar, sobra gente a mais, mas ninguém some da equipe.
  @override
  Future<void> trocarEquipe(
      String supervisorMatricula, List<Map<String, String>> encarregados) async {
    if (encarregados.isNotEmpty) {
      await _cliente.from(tabela).upsert([
        for (final e in encarregados)
          {'supervisor_matricula': supervisorMatricula, ...e},
      ], onConflict: 'supervisor_matricula,encarregado_matricula');
    }
    var remover = _cliente
        .from(tabela)
        .delete()
        .eq('supervisor_matricula', supervisorMatricula);
    if (encarregados.isNotEmpty) {
      // Lista, não texto: o pacote põe as aspas e escapa o que precisar.
      remover = remover.not('encarregado_matricula', 'in',
          [for (final e in encarregados) e['encarregado_matricula']]);
    }
    await remover;
  }
}
