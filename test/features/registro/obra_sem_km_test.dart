import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/core/obra/config_da_obra.dart';
import 'package:namer_app/core/utils/utm.dart';
import 'package:namer_app/features/registro/domain/entities/registro.dart';
import 'package:namer_app/features/registro/presentation/viewmodels/formulario_de_registro.dart';
import 'package:namer_app/features/registro/data/datasources/estaqueamento_service.dart';
import 'package:namer_app/features/registro/data/repositories/catalogo_da_obra_csv.dart';
import 'package:namer_app/features/registro/domain/entities/estaca_do_projeto.dart';
import 'package:namer_app/features/registro/domain/regras/correcao_de_registro.dart';
import 'package:namer_app/features/registro/domain/regras/vias_estaqueamento.dart';

import 'fakes.dart';

// Obra que não usa quilometragem (filiais.config com "usa_km": false): o local
// é o trecho e a estaca, e o registro vai com o KM em branco. Os testes usam
// o KMxEst.csv do APK, com o D2 como se fosse dessa obra.
const _obraSemKm = ConfigDaObra(zonaUtm: ZonaUtm(24), usaKm: false);

const _e57 = EstacaDoProjeto(
    trecho: 'D2', numero: 57, rotulo: '57', km: '231', via: null);
const _e62 = EstacaDoProjeto(
    trecho: 'D2', numero: 62, rotulo: '62', km: '232', via: null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => definirObraAtual(configPadrao));

  group('configuração', () {
    test('sem a chave, a obra usa KM', () {
      final config = ConfigDaObra.deJson(const {});
      expect(config.usaKm, isTrue);
      expect(config.trechosSemKm, isEmpty);
    });

    test('lê usa_km e trechos_sem_km e devolve no mesmo formato', () {
      final config = ConfigDaObra.deJson(const {
        'usa_km': false,
        'trechos_sem_km': ['Trecho Novo'],
      });
      expect(config.usaKm, isFalse);
      expect(config.trechosSemKm, ['Trecho Novo']);
      final json = config.paraJson();
      expect(json['usa_km'], isFalse);
      expect(json['trechos_sem_km'], ['Trecho Novo']);
    });

    test('obra sem KM não pede KM em trecho nenhum', () {
      definirObraAtual(_obraSemKm);
      expect(trechoTemKm(null), isFalse);
      expect(trechoTemKm('D2'), isFalse);
    });

    test('obra com KM pode ter trechos sem KM', () {
      definirObraAtual(const ConfigDaObra(
          zonaUtm: ZonaUtm(24), trechosSemKm: ['Trecho Novo']));
      expect(trechoTemKm('D2'), isTrue);
      expect(trechoTemKm('trecho  novo'), isFalse);
    });

    test('a obra 010152 continua pedindo KM', () {
      expect(trechoTemKm('C1'), isTrue);
      expect(trechoTemKm(null), isTrue);
    });
  });

  group('textos sem KM', () {
    test('faixa e texto do KM em branco não deixam "KM" solto', () {
      expect(faixaDeKm('', ''), '');
      expect(textoDoKm('', ''), '');
      expect(textoDoKm('231', '232'), 'KM 231 a 232');
    });

    test('a lista de estacas não mostra o KM', () {
      expect(rotuloComKm(_e62, '', usaKm: false), '62');
      expect(rotuloComKm(_e62, ''), '62 (KM 232)');
    });
  });

  group('formulário', () {
    late FormularioDeRegistro f;

    // Planilhas e estacas de verdade (as do APK): é a obra sem KM que está
    // sendo testada.
    setUp(() {
      definirObraAtual(_obraSemKm);
      f = FormularioDeRegistro(
        catalogo: const CatalogoDaObraCsv(),
        estacas: EstaqueamentoService.instancia,
        localizacao: LocalizacaoFalsa(),
        registros: RegistrosFalsos(),
        ditado: DitadoFalso(),
      );
    });
    tearDown(() => f.dispose());

    test('o local pede só trecho e estacas', () {
      expect(f.pedeKm, isFalse);
      expect(f.erroDoLocal(), contains('trecho'));
      f.trecho = 'D2';
      expect(f.podeEscolherEstaca, isTrue);
      expect(f.erroDoLocal(), contains('estaca'));
      f
        ..estacaInicial = '57'
        ..estacaFinal = '62';
      expect(f.erroDoLocal(), isNull);
      expect(f.avancar(), isNull);
    });

    test('escolher o trecho lista as estacas de todos os KMs', () async {
      await f.escolherTrecho('D2');
      expect(f.kms, isEmpty);
      expect(f.estacasDoIntervalo.map((e) => e.km).toSet().length,
          greaterThan(kmsVizinhos * 2 + 1));
      expect(f.rotulosDoIntervalo.where((r) => r.contains('KM')), isEmpty);
      expect(f.indiceDoKm, isNull);
      final numeros = f.estacasDoIntervalo.map((e) => e.numero).toList();
      expect(numeros, orderedEquals([...numeros]..sort()));
    });

    test('o resumo não fala de KM', () {
      f
        ..trecho = 'D2'
        ..km = '231'
        ..estacaInicial = '57'
        ..estacaFinal = '62';
      expect(f.resumoDoLocal, 'D2 · est. 57 – 62');
    });

    test('importar um registro sem KM traz o trecho e as estacas', () async {
      await f.importar(Registro(
        usuarioId: 1,
        trecho: 'D2',
        km: '',
        via: '',
        atividade: 'Terraplanagem',
        estacaInicial: '57',
        estacaFinal: '62',
        servicoNotavel: 'S',
        descricao: '',
        criadoEm: '',
      ));
      expect(f.km, isNull);
      expect(f.estacasDoIntervalo, isNotEmpty);
      expect(f.erroDoLocal(), isNull);
    });
  });

  group('edição', () {
    setUp(() => definirObraAtual(_obraSemKm));

    test('não pede KM e grava o KM em branco', () {
      final r = montarCamposCorrigidos(
        trecho: 'D2',
        km: null,
        via: null,
        estacaInicial: _e57,
        estacaFinal: _e62,
        atividade: 'Terraplanagem',
        servico: 'S',
        passo: null,
        pedePasso: false,
        textoQuantidade: '',
        unidade: null,
        descricao: '',
      );
      expect(r.erro, isNull);
      expect(r.campos!.km, '');
      expect(r.campos!.kmFinal, '');
      expect([r.campos!.estacaInicial, r.campos!.estacaFinal], ['57', '62']);
    });
  });
}
