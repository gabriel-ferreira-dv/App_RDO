import '../../domain/entities/clima_da_equipe.dart';
import '../../domain/entities/paralisacao_da_equipe.dart';

// Linha de paralisacoes_app (o servidor guarda em UTC; a tela usa local).
ParalisacaoDaEquipe paralisacaoDaEquipeDoMapa(Map<String, dynamic> m) =>
    ParalisacaoDaEquipe(
      dispositivoId: (m['dispositivo_id'] as String?) ?? '',
      idLocal: (m['id_local'] as num?)?.toInt() ?? 0,
      usuarioMatricula: (m['usuario_matricula'] as String?) ?? '',
      motivo: (m['motivo'] as String?) ?? '',
      observacao: (m['observacao'] as String?) ?? '',
      trecho: (m['trecho'] as String?) ?? '',
      km: (m['km'] as String?) ?? '',
      inicio: DateTime.tryParse((m['inicio'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      fim: DateTime.tryParse((m['fim'] as String?) ?? '')?.toLocal(),
    );

// Linha de clima_dia_app.
ClimaDaEquipe climaDaEquipeDoMapa(Map<String, dynamic> m) => ClimaDaEquipe(
      manha: (m['clima_manha'] as String?) ?? '',
      tarde: (m['clima_tarde'] as String?) ?? '',
      noite: (m['clima_noite'] as String?) ?? '',
    );
