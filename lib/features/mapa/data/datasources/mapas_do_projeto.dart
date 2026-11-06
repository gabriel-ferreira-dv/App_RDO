import 'dart:io';

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';

import '../../../../core/dados_remotos.dart';
import '../../../../core/localizacao_service.dart';
import '../../../../core/obra/config_da_obra.dart';
import '../../../../core/utils/utm.dart';
import '../../domain/regras/mapas_da_obra.dart';
import 'mapa_estatico.dart' show PecaDoProjeto;
import 'permissao_mapas_service.dart';

// Os mapas do projeto (desenhos da obra cortados em peças), posicionados no
// mapa: a grade dos cantos de cada peça, quais mapas o usuário vê e quais
// peças já foram baixadas.

bool envelopesSeCruzam(LatLngBounds a, LatLngBounds b) =>
    a.south <= b.north &&
    a.north >= b.south &&
    a.west <= b.east &&
    a.east >= b.west;

// Grade dos cantos das peças de um mapa, convertida do UTM do mapa no fuso
// da obra.
class GradeDoMapa {
  final int linhas;
  final int colunas;
  final String pastaDasPecas;
  final List<List<LatLng>> _cantos;

  GradeDoMapa(MapaInfo mapa)
      : linhas = mapa.linhas,
        colunas = mapa.colunas,
        pastaDasPecas = mapa.assetDir,
        _cantos = List.generate(
          mapa.linhas + 1,
          (l) => List.generate(
            mapa.colunas + 1,
            (c) => utmParaLatLng(
              mapa.swE + (mapa.neE - mapa.swE) * c / mapa.colunas,
              mapa.neN - (mapa.neN - mapa.swN) * l / mapa.linhas,
            ),
          ),
        );

  LatLng canto(int linha, int coluna) => _cantos[linha][coluna];

  LatLng get sudoeste => _cantos[linhas][0];
  LatLng get nordeste => _cantos[0][colunas];
  LatLngBounds get envelope => LatLngBounds(sudoeste, nordeste);

  LatLng get centro => LatLng(
        (sudoeste.latitude + nordeste.latitude) / 2,
        (sudoeste.longitude + nordeste.longitude) / 2,
      );

  LatLngBounds envelopeDaPeca(int linha, int coluna) =>
      LatLngBounds.fromPoints([
        canto(linha, coluna),
        canto(linha, coluna + 1),
        canto(linha + 1, coluna),
        canto(linha + 1, coluna + 1),
      ]);

  // Nome da peça no arquivo, sem extensão: "03_7".
  static String chaveDaPeca(int linha, int coluna) =>
      '${linha.toString().padLeft(2, '0')}_$coluna';
}

// Grades dos mapas da obra em uso; refeitas só quando a obra muda.
ConfigDaObra? _obraDasGrades;
Map<String, GradeDoMapa> _gradesPorNome = const {};

Map<String, GradeDoMapa> _grades() {
  if (!identical(_obraDasGrades, obraAtual)) {
    _gradesPorNome = {for (final m in obraAtual.mapas) m.nome: GradeDoMapa(m)};
    _obraDasGrades = obraAtual;
  }
  return _gradesPorNome;
}

// Mapas dos grupos do usuário (ver PermissaoMapasService).
List<GradeDoMapa> mapasVisiveis() {
  final grades = _grades();
  return [
    for (final info
        in mapasDosGrupos(PermissaoMapasService.instancia.grupos.value))
      if (grades[info.nome] case final grade?) grade,
  ];
}

// Peças já baixadas dos mapas do usuário que cruzam [area], com os cantos no
// mapa (para o mapa do relatório).
List<PecaDoProjeto> pecasDoProjetoEm(LatLngBounds area) {
  final dir = dirDadosRemotos;
  if (dir == null) return const [];
  final pecas = <PecaDoProjeto>[];
  for (final grade in mapasVisiveis()) {
    if (!envelopesSeCruzam(area, grade.envelope)) continue;
    final pasta = grade.pastaDasPecas.split('/').last;
    for (var l = 0; l < grade.linhas; l++) {
      for (var c = 0; c < grade.colunas; c++) {
        if (!envelopesSeCruzam(area, grade.envelopeDaPeca(l, c))) continue;
        final arquivo =
            '${dir.path}/$pasta/${GradeDoMapa.chaveDaPeca(l, c)}.webp';
        if (!File(arquivo).existsSync()) continue;
        pecas.add(PecaDoProjeto(
          arquivo: arquivo,
          topoEsquerda: grade.canto(l, c),
          baseEsquerda: grade.canto(l + 1, c),
          baseDireita: grade.canto(l + 1, c + 1),
        ));
      }
    }
  }
  return pecas;
}

// Obra sem mapa: o centro do D2 (o GPS corrige logo em seguida).
final LatLng _centroReserva = GradeDoMapa(configPadrao.mapas.first).centro;

// Centro do primeiro mapa da obra, até o GPS dar a primeira posição.
LatLng get centroInicial {
  final grades = _grades().values;
  return grades.isEmpty ? _centroReserva : grades.first.centro;
}

// Última posição filtrada do GPS (a mesma do carimbo), ou o centro da obra.
LatLng get locAtual =>
    LocalizacaoService.instancia.posicao.value?.ponto ?? centroInicial;
