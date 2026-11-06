import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/registro/presentation/viewmodels/formulario_de_registro.dart';

import 'fakes.dart';

// Só as regras que não dependem dos CSVs nem do banco: o que falta em cada
// etapa e a medição. A obra é a padrão (configPadrao): o C1 tem via e
// estaca; o Pátio de Vigas não tem nenhuma das duas.
void main() {
  late FormularioDeRegistro f;

  setUp(() => f = formularioDeTeste());
  tearDown(() => f.dispose());

  test('o local pede trecho, KM, via e as duas estacas, nessa ordem', () {
    expect(f.erroDoLocal(), contains('trecho'));
    f.trecho = 'C1';
    expect(f.erroDoLocal(), contains('KM'));
    f.km = '225';
    expect(f.erroDoLocal(), contains('via'));
    f.via = 'Via 02 Norte';
    expect(f.erroDoLocal(), contains('estaca'));
    f.estacaInicial = '1115';
    expect(f.erroDoLocal(), contains('estaca'));
    f.estacaFinal = '1120';
    expect(f.erroDoLocal(), isNull);
  });

  test('área de apoio não pede via nem estaca', () {
    f.trecho = 'PATIO DE VIGAS';
    f.km = '1';
    expect(f.pedeVia, isFalse);
    expect(f.pedeEstaca, isFalse);
    expect(f.erroDoLocal(), isNull);
  });

  test('avançar só passa para o serviço com o local completo', () {
    expect(f.avancar(), isNotNull);
    expect(f.etapa, EtapaDoRegistro.local);
    f
      ..trecho = 'PATIO DE VIGAS'
      ..km = '1';
    expect(f.avancar(), isNull);
    expect(f.etapa, EtapaDoRegistro.servico);
    f.voltar();
    expect(f.etapa, EtapaDoRegistro.local);
  });

  test('o serviço pede atividade, serviço e passo', () {
    expect(f.erroDoServico(), contains('atividade'));
    f.atividade = 'Terraplanagem';
    expect(f.erroDoServico(), contains('serviço'));
    f.servico = 'COMPACTAÇÃO DE ATERRO';
    expect(f.erroDoServico(), contains('passo'));
    f.passo = 'Aterro na saia';
    expect(f.erroDoServico(), isNull);
  });

  test('quantidade e unidade vêm juntas ou nenhuma', () {
    f
      ..atividade = 'Terraplanagem'
      ..servico = 'S'
      ..passo = 'P';

    f.quantidade.text = '12,5';
    expect(f.quantidadeInformada(), 12.5);
    expect(f.erroDoServico(), contains('unidade'));

    f.unidade = 'm³';
    expect(f.erroDoServico(), isNull);

    f.quantidade.text = 'doze';
    expect(f.erroDoServico(), contains('inválida'));

    f.quantidade.clear();
    expect(f.erroDoServico(), contains('quantidade'));
  });

  test('depois das fotos a medição zera e o local fica', () {
    f
      ..trecho = 'C1'
      ..km = '225'
      ..unidade = 'm³'
      ..etapa = EtapaDoRegistro.servico;
    f.quantidade.text = '10';
    f.depoisDasFotos();
    expect(f.quantidade.text, isEmpty);
    expect(f.unidade, isNull);
    expect(f.etapa, EtapaDoRegistro.local);
    expect(f.trecho, 'C1');
  });

  test('resumo do local para o topo da etapa Serviço', () {
    f
      ..trecho = 'C1'
      ..km = '225'
      ..estacaInicial = '1115'
      ..estacaFinal = '1120';
    expect(f.resumoDoLocal, 'C1 · km 225 · est. 1115 – 1120');
  });
}
