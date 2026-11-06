import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// O cálculo do dia de trabalho mora no core (Dart puro); continua acessível
// por aqui para quem já importa este arquivo.
export '../../core/obra/dia_de_trabalho.dart';

// Matrículas do turno da noite (tabela turno_noturno do Supabase). Fica
// guardado no aparelho, para o relatório sair certo sem sinal.
class TurnoNoturnoService {
  TurnoNoturnoService._interno();
  static final TurnoNoturnoService instancia = TurnoNoturnoService._interno();

  static const String tabela = 'turno_noturno';
  static const String _chavePrefs = 'matriculas_turno_noturno';

  final ValueNotifier<Set<String>> _matriculas = ValueNotifier({});

  // Avisa quando a lista muda (ex.: chegou do servidor depois de a tela
  // abrir), para quem calcula o dia de trabalho refazer a conta.
  Listenable get mudancas => _matriculas;

  bool ehNoturno(String matricula) {
    final m = matricula.trim();
    return m.isNotEmpty && _matriculas.value.contains(m);
  }

  void _trocar(Set<String> matriculas) {
    if (!setEquals(matriculas, _matriculas.value)) {
      _matriculas.value = matriculas;
    }
  }

  // Lê a lista guardada no aparelho (no boot).
  Future<void> carregarDoAparelho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _trocar((prefs.getStringList(_chavePrefs) ?? const []).toSet());
    } catch (e) {
      debugPrint('Turno noturno: falha ao ler do aparelho: $e');
    }
  }

  // Busca no servidor e guarda no aparelho; sem rede, vale a guardada.
  Future<void> sincronizar() async {
    try {
      final linhas =
          await Supabase.instance.client.from(tabela).select('matricula');
      final matriculas = {
        for (final linha in linhas) ((linha['matricula'] as String?) ?? '').trim(),
      }..removeWhere((m) => m.isEmpty);
      _trocar(matriculas);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_chavePrefs, matriculas.toList());
    } catch (e) {
      debugPrint('Turno noturno: falha ao sincronizar: $e');
    }
  }
}
