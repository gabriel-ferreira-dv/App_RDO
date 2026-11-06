import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/registro/domain/entities/registro.dart';
import 'package:namer_app/features/registro/domain/entities/sugestao_gps.dart';
import 'package:namer_app/features/registro/presentation/viewmodels/formulario_de_registro.dart';

import 'fakes.dart';

// Os fluxos do formulário com as planilhas, as estacas, o GPS, o banco e o
// ditado falsos (ver fakes.dart). A obra é a padrão: o C1 tem KM, via e
// estaca.
void main() {
  late RegistrosFalsos registros;
  late LocalizacaoFalsa localizacao;
  late DitadoFalso ditado;
  late FormularioDeRegistro f;

  setUp(() {
    registros = RegistrosFalsos();
    localizacao = LocalizacaoFalsa();
    ditado = DitadoFalso();
    f = formularioDeTeste(
        registros: registros, localizacao: localizacao, ditado: ditado);
  });
  tearDown(() => f.dispose());

  Future<void> preencherLocal() async {
    await f.escolherTrecho('C1');
    await f.escolherKm('225');
    await f.escolherVia('Via 02 Norte');
    f.escolherEstacaInicial('1115');
    f.escolherEstacaFinal('1125 (KM 226)');
  }

  test('a cascata do local: trecho → KM → via → estacas', () async {
    await f.escolherTrecho('C1');
    expect(f.kms, ['224', '225', '226']);
    expect(f.atividades, isEmpty, reason: 'só depois do KM');

    await f.escolherKm('225');
    expect(f.atividades, ['Terraplanagem', 'Drenagem']);
    expect(f.estacasDoIntervalo, isEmpty, reason: 'pista dupla espera a via');

    await f.escolherVia('Via 02 Norte');
    expect(f.rotulosDoIntervalo,
        ['1110 (KM 224)', '1115', '1120', '1125 (KM 226)']);
    expect(f.indiceDoKm, 1);
  });

  test('a estaca final de outro KM vira faixa de KM no resumo', () async {
    await preencherLocal();
    expect(f.estacaFinal, '1125');
    expect(f.rotuloNoCampo(f.estacaFinal), '1125 (KM 226)');
    expect(f.resumoDoLocal, 'C1 · km 225 a 226 · est. 1115 – 1125');
    expect(f.erroDoLocal(), isNull);
  });

  test('trocar o trecho zera o que vem depois', () async {
    await preencherLocal();
    await f.escolherTrecho('PATIO DE VIGAS');
    expect([f.km, f.via, f.estacaInicial, f.estacaFinal, f.atividade],
        everyElement(isNull));
    // Área de apoio: tem KM, mas não tem via nem estaca.
    expect(f.pedeVia, isFalse);
    expect(f.pedeEstaca, isFalse);
  });

  test('gravar: KM de cada ponta pela estaca e a medição', () async {
    await preencherLocal();
    await f.escolherAtividade('Terraplanagem');
    await f.escolherServico('COMPACTAÇÃO DE ATERRO');
    f.escolherPasso('Aterro na saia');
    f.quantidade.text = '120,5';
    f.escolherUnidade('m³');
    f.descricao.text = 'Aterro compactado';
    expect(f.erroDoServico(), isNull);

    final paraFotos = await f.gravar(7);
    expect(registros.criados.single, {
      'usuarioId': 7,
      'trecho': 'C1',
      'km': '225',
      'kmFinal': '226',
      'via': 'Via 02 Norte',
      'atividade': 'Terraplanagem',
      'estacaInicial': '1115',
      'estacaFinal': '1125',
      'servico': 'COMPACTAÇÃO DE ATERRO',
      'passo': 'Aterro na saia',
      'quantidade': 120.5,
      'unidade': 'm³',
      'descricao': 'Aterro compactado',
    });
    expect(paraFotos.registroId, 1);
    expect(paraFotos.faixaDeKm, '225 a 226');

    // Depois das fotos: a medição sai, o local fica para o próximo.
    f.depoisDasFotos();
    expect(f.quantidade.text, isEmpty);
    expect(f.unidade, isNull);
    expect(f.trecho, 'C1');
    expect(f.etapa, EtapaDoRegistro.local);
  });

  test('GPS: preenche o local e diz onde a pessoa está', () async {
    localizacao.resultado = ResultadoSugestaoGps.ok(SugestaoGps(
      trecho: 'C1',
      km: '225',
      estaca: '1115',
      distanciaMetros: 42,
      via: 'Via 02 Norte',
    ));
    final mensagem = await f.preencherPelaLocalizacao();
    expect(mensagem, 'Você está a 42 m da Estaca 1115 no Trecho C1, KM 225');
    expect([f.trecho, f.km, f.via, f.estacaInicial],
        ['C1', '225', 'Via 02 Norte', '1115']);
    expect(f.atividades, isNotEmpty);
    expect(f.estacasDoIntervalo, hasLength(4));
    expect(f.buscandoGps, isFalse);
  });

  test('GPS sem sinal: devolve o motivo e não mexe no local', () async {
    final mensagem = await f.preencherPelaLocalizacao();
    expect(mensagem, 'Ative a localização (GPS) do aparelho');
    expect(f.trecho, isNull);
  });

  test('importar copia o local e o serviço, mas não a medição', () async {
    await f.importar(Registro(
      usuarioId: 1,
      trecho: 'C1',
      km: '225',
      via: 'Via 02 Norte',
      atividade: 'Terraplanagem',
      estacaInicial: '1115',
      estacaFinal: '1120',
      servicoNotavel: 'COMPACTAÇÃO DE ATERRO',
      servicoNotavelDetalhe: 'Acabamento',
      quantidade: 3,
      unidade: 'm',
      descricao: 'Do dia anterior',
      criadoEm: '2026-10-20T12:00:00.000Z',
    ));
    expect([f.trecho, f.km, f.via, f.estacaInicial, f.estacaFinal],
        ['C1', '225', 'Via 02 Norte', '1115', '1120']);
    expect([f.atividade, f.servico, f.passo],
        ['Terraplanagem', 'COMPACTAÇÃO DE ATERRO', 'Acabamento']);
    expect(f.passos, ['Aterro na saia', 'Acabamento']);
    expect(f.quantidade.text, isEmpty);
    expect(f.unidade, isNull);
    expect(f.descricao.text, 'Do dia anterior');
  });

  group('Ditado', () {
    test('sem reconhecimento de voz no aparelho, avisa', () async {
      ditado.disponivel = false;
      expect(await f.alternarDitado(),
          'Reconhecimento de voz não disponível neste aparelho');
      expect(f.ditando, isFalse);
    });

    test('o texto ditado entra depois do que já estava escrito', () async {
      f.descricao.text = 'Pista';
      expect(await f.alternarDitado(), isNull);
      expect(f.ditando, isTrue);
      ditado.falar('alagada no KM 225');
      expect(f.descricao.text, 'Pista alagada no KM 225');
      ditado.falar('alagada no KM 225.', fim: true);
      expect(f.ditando, isFalse);
    });

    test('tocar de novo para o ditado', () async {
      await f.alternarDitado();
      await f.alternarDitado();
      expect(f.ditando, isFalse);
      expect(ditado.ouvindo, isFalse);
    });
  });
}
