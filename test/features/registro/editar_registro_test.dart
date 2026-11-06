import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/registro/data/datasources/edicao_registro_service.dart';
import 'package:namer_app/features/registro/domain/entities/estaca_do_projeto.dart';
import 'package:namer_app/features/registro/domain/regras/correcao_de_registro.dart';

const _e1115 = EstacaDoProjeto(
    trecho: 'C1', numero: 1115, rotulo: '1115', km: '225', via: 'Via 02 Norte');
const _e1120 = EstacaDoProjeto(
    trecho: 'C1', numero: 1120, rotulo: '1120', km: '225', via: 'Via 02 Norte');
const _e1170 = EstacaDoProjeto(
    trecho: 'C1', numero: 1170, rotulo: '1170', km: '226', via: 'Via 02 Norte');

({CamposDoRegistro? campos, String? erro}) _montar({
  String? trecho = 'C1',
  String? km = '225',
  String? via = 'Via 02 Norte',
  EstacaDoProjeto? inicial = _e1115,
  EstacaDoProjeto? fim = _e1120,
  String? atividade = 'Terraplanagem',
  String? servico = 'COMPACTAÇÃO DE ATERRO',
  String? passo = 'Espalhamento',
  bool pedePasso = true,
  String quantidade = '',
  String? unidade,
  String descricao = ' aterro na saia ',
}) =>
    montarCamposCorrigidos(
      trecho: trecho,
      km: km,
      via: via,
      estacaInicial: inicial,
      estacaFinal: fim,
      atividade: atividade,
      servico: servico,
      passo: passo,
      pedePasso: pedePasso,
      textoQuantidade: quantidade,
      unidade: unidade,
      descricao: descricao,
    );

void main() {
  group('montarCamposCorrigidos', () {
    test('registro completo vira os campos corrigidos', () {
      final c = _montar(quantidade: '120,5', unidade: 'm³').campos!;
      expect(c.trecho, 'C1');
      expect(c.km, '225');
      expect(c.kmFinal, '');
      expect(c.via, 'Via 02 Norte');
      expect([c.estacaInicial, c.estacaFinal], ['1115', '1120']);
      expect(c.quantidade, 120.5);
      expect(c.unidade, 'm³');
      expect(c.descricao, 'aterro na saia');
    });

    test('estaca final em outro KM preenche o KM final', () {
      final c = _montar(fim: _e1170).campos!;
      expect(c.km, '225');
      expect(c.kmFinal, '226');
    });

    test('pede o que o formulário de registro pede', () {
      expect(_montar(trecho: null).erro, 'Selecione o trecho');
      expect(_montar(km: null).erro, 'Selecione o KM');
      expect(_montar(via: null).erro, 'Selecione o sentido da via');
      expect(_montar(fim: null).erro, 'Selecione a estaca inicial e final');
      expect(_montar(servico: null).erro, 'Selecione o serviço');
      expect(_montar(passo: null).erro, 'Selecione o passo do serviço');
      // Serviço sem passos na planilha: o passo fica em branco.
      expect(
          _montar(passo: null, pedePasso: false).campos!.servicoNotavelDetalhe,
          '');
    });

    test('a medição precisa de quantidade e unidade juntas', () {
      expect(_montar(quantidade: 'abc', unidade: 'm').erro,
          startsWith('Quantidade inválida'));
      expect(_montar(quantidade: '10').erro, 'Escolha a unidade da quantidade');
      expect(_montar(unidade: 'm').erro, 'Informe a quantidade da medição');
    });

    test('área de apoio não leva via nem estaca', () {
      final c = _montar(
              trecho: 'CANTEIRO INDUSTRIAL',
              via: null,
              inicial: null,
              fim: null)
          .campos!;
      expect(c.via, '');
      expect([c.estacaInicial, c.estacaFinal], ['', '']);
    });
  });

  group('CamposDoRegistro', () {
    test('quantidade inteira do servidor é a mesma que a do aparelho', () {
      final doServidor = CamposDoRegistro.deMapa({
        'trecho': 'C1',
        'km': '225',
        'atividade': 'Drenagem',
        'servico_notavel': 'X',
        'quantidade': 120
      });
      final doAparelho = CamposDoRegistro.deMapa({
        'trecho': 'C1',
        'km': '225',
        'atividade': 'Drenagem',
        'servico_notavel': 'X',
        'quantidade': 120.0
      });
      expect(doServidor.mesmoQue(doAparelho), isTrue);
    });

    test('qualquer campo diferente conta como correção', () {
      final antes = _montar().campos!;
      final depois = _montar(descricao: 'outra').campos!;
      expect(antes.mesmoQue(depois), isFalse);
    });

    test('só os campos editáveis vão para o servidor', () {
      expect(
          _montar().campos!.paraMapa().keys,
          unorderedEquals([
            'trecho',
            'km',
            'km_final',
            'via',
            'atividade',
            'estaca_inicial',
            'estaca_final',
            'servico_notavel',
            'servico_notavel_detalhe',
            'quantidade',
            'unidade',
            'descricao',
          ]));
    });
  });
}
