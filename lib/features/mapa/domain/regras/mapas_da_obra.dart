// Mapas do projeto: vêm da configuração da obra (core/obra/config_da_obra.dart).
// Mapa novo: entrada em `mapas` na config da filial (Supabase) e o .zip no
// bucket `dados`, com o mesmo nome em versoes_dados.

import '../../../../core/obra/config_da_obra.dart';

export '../../../../core/obra/config_da_obra.dart'
    show MapaInfo, grupoCbm, grupoSubContratada;

List<MapaInfo> get mapasConfig => obraAtual.mapas;

// Mapas visíveis para estes [grupos].
List<MapaInfo> mapasDosGrupos(Set<String> grupos) =>
    [for (final mapa in mapasConfig) if (grupos.contains(mapa.grupo)) mapa];

// true se [nome] (vindo da tabela versoes_dados) é um mapa — e não um CSV.
bool ehNomeDeMapa(String nome) => mapasConfig.any((m) => m.nome == nome);

// Grupo do mapa [nome]; [grupoCbm] se desconhecido.
String grupoDoMapa(String nome) {
  for (final m in mapasConfig) {
    if (m.nome == nome) return m.grupo;
  }
  return grupoCbm;
}

// Nome amigável de um mapa; cai para um genérico se não estiver cadastrado.
String rotuloDoMapa(String nome) {
  for (final m in mapasConfig) {
    if (m.nome == nome) return m.rotulo;
  }
  return 'Mapa ($nome)';
}
