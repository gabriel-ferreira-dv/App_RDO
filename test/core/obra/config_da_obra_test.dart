import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/obra/config_da_obra.dart';
import 'package:namer_app/core/utils/utm.dart';
import 'package:namer_app/features/mapa/domain/regras/mapas_da_obra.dart';
import 'package:namer_app/features/obra/config_da_obra_service.dart';
import 'package:namer_app/features/registro/domain/regras/atividades_descricoes.dart';
import 'package:namer_app/features/registro/domain/regras/vias_estaqueamento.dart';

// Uma obra sem pista dupla, em outro fuso e com um mapa só.
const _outraObra = ConfigDaObra(
  zonaUtm: ZonaUtm(23),
  trechosSemEstaca: ['Galpão de Apoio'],
  mapas: [
    MapaInfo('Lote_1', 'Mapa do lote 1',
        swE: 600000,
        swN: 7500000,
        neE: 601000,
        neN: 7501000,
        linhas: 4,
        colunas: 4),
  ],
  descricoesAtividades: {'Fundação': 'Estacas e blocos.'},
);

void main() {
  tearDown(() => definirObraAtual(configPadrao));

  test('a config da obra atual volta igual do JSON', () {
    final json = jsonEncode(configPadrao.paraJson());
    final volta = ConfigDaObra.deJson(jsonDecode(json) as Map<String, dynamic>);
    expect(jsonEncode(volta.paraJson()), json);
  });

  test('config vazia ou nula do servidor vale a obra atual', () {
    expect(configDoServidor(null), same(configPadrao));
    expect(configDoServidor(<String, dynamic>{}), same(configPadrao));
  });

  test('config parcial de outra obra não herda os mapas nem as vias desta', () {
    final config = ConfigDaObra.deJson({'fuso_utm': 23});
    expect(config.mapas, isEmpty);
    expect(config.vias, isNull);
    expect(config.zonaUtm, const ZonaUtm(23));
  });

  group('com outra obra em uso', () {
    setUp(() => definirObraAtual(_outraObra));

    test('sem pista dupla o formulário nunca pede a via', () {
      expect(trechoTemVia(null), isFalse);
      expect(trechoTemVia('Lote 1'), isFalse);
      expect(estacaDaSerieSul(2500), isFalse);
    });

    test('as áreas sem estaca são as da obra, sem depender de acento', () {
      expect(trechoTemEstaca('GALPAO DE APOIO'), isFalse);
      expect(trechoTemEstaca('Lote 1'), isTrue);
      expect(trechoTemEstaca('PATIO DE VIGAS'), isTrue);
    });

    test('os mapas e as descrições são os da obra', () {
      expect(mapasConfig.map((m) => m.nome), ['Lote_1']);
      expect(ehNomeDeMapa('D2'), isFalse);
      expect(descricaoDaAtividade('Fundação'), 'Estacas e blocos.');
      expect(descricaoDaAtividade('Drenagem'), isNull);
    });

    test('as coordenadas passam a usar o fuso da obra', () {
      expect(zonaUtmAtual, const ZonaUtm(23));
      // E = 500000 é o meridiano central: -45° no fuso 23, -39° no 24.
      expect(utmParaLatLng(500000, 7800000).longitude, closeTo(-45, 1e-6));
      expect(utmParaLatLng(500000, 7800000, zona: const ZonaUtm(24)).longitude,
          closeTo(-39, 1e-6));
    });
  });

  test('voltar para a obra atual restaura vias, fuso e mapas', () {
    definirObraAtual(_outraObra);
    definirObraAtual(configPadrao);
    expect(viaSul, 'Via 01 Sul');
    expect(viaNorte, 'Via 02 Norte');
    expect(zonaUtmAtual, const ZonaUtm(24));
    expect(mapasConfig.map((m) => m.nome), contains('D2'));
  });
}
