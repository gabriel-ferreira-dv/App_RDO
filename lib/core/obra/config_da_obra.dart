import 'package:flutter/foundation.dart';

import '../utils/utm.dart';

// Configuração da obra: o que muda de uma obra para outra além dos CSVs
// (fuso UTM, vias, trechos sem via ou sem estaca, mapas do projeto e
// descrições das atividades). Vem da coluna `config` da tabela `filiais` do
// Supabase (ver ConfigDaObraService); sem ela, vale a obra atual
// ([configPadrao]).

// Grupos de mapa; cada usuário tem um ou os dois (ver PermissaoMapasService).
const String grupoCbm = 'CBM';
const String grupoSubContratada = 'SUB CONTRATADA';

// Um mapa do projeto. O `nome` precisa bater em três lugares: a pasta
// assets/overlays/<nome> (origem do .zip), a pasta baixada dados_remotos/<nome>
// e a coluna `nome` de versoes_dados. O .zip no bucket deve ter nome sem acento.
class MapaInfo {
  // Identificador e nome da pasta (assets e dados_remotos).
  final String nome;

  // Rótulo amigável para diálogos e avisos.
  final String rotulo;

  // Grupo que dá acesso a este mapa.
  final String grupo;

  // Cantos sudoeste e nordeste do desenho em UTM, no fuso da obra.
  final double swE;
  final double swN;
  final double neE;
  final double neN;

  // Grade de tiles em que o desenho foi cortado (tool/split_overlay.dart).
  final int linhas;
  final int colunas;

  const MapaInfo(
    this.nome,
    this.rotulo, {
    this.grupo = grupoCbm,
    required this.swE,
    required this.swN,
    required this.neE,
    required this.neN,
    required this.linhas,
    required this.colunas,
  });

  String get assetDir => 'assets/overlays/$nome';

  factory MapaInfo.deJson(Map<String, dynamic> json) => MapaInfo(
        json['nome'] as String,
        (json['rotulo'] as String?) ?? 'Mapa (${json['nome']})',
        grupo: (json['grupo'] as String?) ?? grupoCbm,
        swE: (json['sw_e'] as num).toDouble(),
        swN: (json['sw_n'] as num).toDouble(),
        neE: (json['ne_e'] as num).toDouble(),
        neN: (json['ne_n'] as num).toDouble(),
        linhas: (json['linhas'] as num).toInt(),
        colunas: (json['colunas'] as num).toInt(),
      );

  Map<String, dynamic> paraJson() => {
        'nome': nome,
        'rotulo': rotulo,
        'grupo': grupo,
        'sw_e': swE,
        'sw_n': swN,
        'ne_e': neE,
        'ne_n': neN,
        'linhas': linhas,
        'colunas': colunas,
      };
}

// Vias de pista dupla. Nesta obra, no C1, a Via 02 Norte é a série 1000 e a
// Via 01 Sul a 2000 (a 2115 fica ao lado da 1115); no D2 há uma série só e a
// via é escolhida pelo usuário.
class ViasDaObra {
  // Via da numeração principal e via da segunda série.
  final String primeiraSerie;
  final String segundaSerie;

  // Primeira estaca da segunda série; null quando a numeração não separa as
  // vias (o usuário escolhe a via).
  final int? inicioSegundaSerie;

  // Distância entre as duas numerações: a estaca 1115 vira 2115 na outra pista.
  final int deslocamento;

  const ViasDaObra({
    required this.primeiraSerie,
    required this.segundaSerie,
    this.inicioSegundaSerie,
    this.deslocamento = 0,
  });

  factory ViasDaObra.deJson(Map<String, dynamic> json) => ViasDaObra(
        primeiraSerie: json['primeira_serie'] as String,
        segundaSerie: json['segunda_serie'] as String,
        inicioSegundaSerie: (json['inicio_segunda_serie'] as num?)?.toInt(),
        deslocamento: (json['deslocamento'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> paraJson() => {
        'primeira_serie': primeiraSerie,
        'segunda_serie': segundaSerie,
        'inicio_segunda_serie': inicioSegundaSerie,
        'deslocamento': deslocamento,
      };
}

class ConfigDaObra {
  final ZonaUtm zonaUtm;

  // null: obra sem pista dupla, o formulário nunca pergunta a via.
  final ViasDaObra? vias;

  // Trechos de pista simples e áreas de apoio: o formulário não pergunta a via.
  final List<String> trechosSemVia;

  // Áreas de apoio sem estaqueamento de projeto: o formulário não pede estaca.
  final List<String> trechosSemEstaca;

  // false: a obra não usa quilometragem, o local é só o trecho e a estaca.
  final bool usaKm;

  // Trechos sem KM numa obra que usa KM: o formulário lista as estacas do
  // trecho inteiro.
  final List<String> trechosSemKm;

  final List<MapaInfo> mapas;

  // Explicação de cada atividade; a chave é o nome exato da coluna Atividade
  // do SevNotaveis.csv.
  final Map<String, String> descricoesAtividades;

  const ConfigDaObra({
    required this.zonaUtm,
    this.vias,
    this.trechosSemVia = const [],
    this.trechosSemEstaca = const [],
    this.usaKm = true,
    this.trechosSemKm = const [],
    this.mapas = const [],
    this.descricoesAtividades = const {},
  });

  // Campo ausente vale o neutro (sem via, sem mapa...), nunca o da obra atual:
  // a configuração de outra obra não pode herdar os mapas desta.
  factory ConfigDaObra.deJson(Map<String, dynamic> json) => ConfigDaObra(
        zonaUtm: ZonaUtm(
          (json['fuso_utm'] as num?)?.toInt() ?? 24,
          sul: (json['hemisferio_sul'] as bool?) ?? true,
        ),
        vias: json['vias'] == null
            ? null
            : ViasDaObra.deJson(Map<String, dynamic>.from(json['vias'] as Map)),
        trechosSemVia: _textos(json['trechos_sem_via']),
        trechosSemEstaca: _textos(json['trechos_sem_estaca']),
        // Ausente vale true: as obras configuradas antes da chave usam KM.
        usaKm: (json['usa_km'] as bool?) ?? true,
        trechosSemKm: _textos(json['trechos_sem_km']),
        mapas: [
          for (final m in (json['mapas'] as List?) ?? const [])
            MapaInfo.deJson(Map<String, dynamic>.from(m as Map)),
        ],
        descricoesAtividades: {
          for (final e
              in ((json['descricoes_atividades'] as Map?) ?? const {}).entries)
            e.key.toString(): e.value.toString(),
        },
      );

  Map<String, dynamic> paraJson() => {
        'fuso_utm': zonaUtm.fuso,
        'hemisferio_sul': zonaUtm.sul,
        'vias': vias?.paraJson(),
        'trechos_sem_via': trechosSemVia,
        'trechos_sem_estaca': trechosSemEstaca,
        'usa_km': usaKm,
        'trechos_sem_km': trechosSemKm,
        'mapas': [for (final m in mapas) m.paraJson()],
        'descricoes_atividades': descricoesAtividades,
      };
}

List<String> _textos(Object? valor) =>
    [for (final v in (valor as List?) ?? const []) v.toString()];

// A obra atual (D2, C1 e Contornos). Vale até a configuração do servidor
// chegar e quando ela está vazia.
const ConfigDaObra configPadrao = ConfigDaObra(
  zonaUtm: ZonaUtm(24),
  vias: ViasDaObra(
    primeiraSerie: 'Via 02 Norte',
    segundaSerie: 'Via 01 Sul',
    inicioSegundaSerie: 2000,
    deslocamento: 1000,
  ),
  trechosSemVia: [
    'CONTORNO DE FUNDAO',
    'CONTORNO DE IBIRACU',
    'CANTEIRO INDUSTRIAL',
    'PATIO DE VIGAS',
  ],
  trechosSemEstaca: [
    'CANTEIRO INDUSTRIAL',
    'PATIO DE VIGAS',
  ],
  mapas: [
    MapaInfo('D2', 'Mapa do trecho D2',
        swE: 351849.7584,
        swN: 7784342.6030,
        neE: 354010.7511,
        neN: 7794250.1072,
        linhas: 90,
        colunas: 25),
    MapaInfo('C1', 'Mapa do trecho C1',
        swE: 351473.537,
        swN: 7796577.542,
        neE: 355442.406,
        neN: 7803295.129,
        linhas: 60,
        colunas: 30),
    MapaInfo('Contorno_Fundão', 'Mapa do Contorno de Fundão',
        swE: 352423.387,
        swN: 7793005.057,
        neE: 354770.603,
        neN: 7797645.351,
        linhas: 30,
        colunas: 15),
    MapaInfo('Contorno_Ibiraçu', 'Mapa do Contorno de Ibiraçu',
        swE: 354902.080,
        swN: 7806251.889,
        neE: 357104.019,
        neN: 7808991.788,
        linhas: 30,
        colunas: 20),
    MapaInfo('GEO_dreno', 'Mapa do GEO dreno',
        grupo: grupoSubContratada,
        swE: 356373.777,
        swN: 7807923.567,
        neE: 356763.392,
        neN: 7808298.461,
        linhas: 10,
        colunas: 10),
  ],
  descricoesAtividades: {
    'Terraplanagem':
        'Preparação e movimentação de terra: limpeza da área, remoções e '
            'demolições, escavações, cargas e transportes, aterros e '
            'compactação — o que conforma o terreno ao greide do projeto.',
    'Drenagem':
        'Dispositivos de captação, condução e disposição das águas pluviais: '
            'bueiros, sarjetas, valetas, meios-fios, caixas coletoras e drenos, '
            'protegendo a via contra erosão e acúmulo de água.',
    'Pavimentação':
        'Camadas do pavimento, do subleito ao revestimento asfáltico: '
            'fresagem, bases e sub-bases, pinturas betuminosas e aplicação de '
            'misturas asfálticas (CBUQ, PMQ), formando a estrutura de rolamento.',
    'Civil':
        'Obras de concreto e estrutura: fundações, estacas, armação, fôrmas, '
            'concretagem, protensão e pré-moldados, além de contenções, '
            'andaimes e os serviços de apoio e acabamento da obra.',
    'Sinalização':
        'Elementos de segurança viária e sinalização: barreiras tipo New '
            'Jersey, defensas, placas e marcações que protegem e orientam o '
            'tráfego.',
  },
);

// Código da filial desta obra; é também a pasta das fotos no bucket.
const String filialPadrao = '010152';

// Configuração em uso; telas que dependem dela (mapa) ouvem o notifier.
final ValueNotifier<ConfigDaObra> obraAtualNotifier =
    ValueNotifier<ConfigDaObra>(configPadrao);

ConfigDaObra get obraAtual => obraAtualNotifier.value;

// Troca a obra em uso, junto com o fuso das conversões UTM.
void definirObraAtual(ConfigDaObra config) {
  zonaUtmAtual = config.zonaUtm;
  obraAtualNotifier.value = config;
}
