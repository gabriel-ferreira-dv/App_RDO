import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/registro/domain/entities/campos_do_registro.dart';
import 'package:namer_app/features/registro/domain/entities/lista_de_estacas.dart';
import 'package:namer_app/features/registro/domain/entities/registro.dart';
import 'package:namer_app/features/registro/presentation/viewmodels/editar_registro_view_model.dart';
import 'package:namer_app/features/registro/presentation/viewmodels/importar_atividade_view_model.dart';

import 'fakes.dart';

const _original = CamposDoRegistro(
  trecho: 'C1',
  km: '225',
  via: 'Via 02 Norte',
  atividade: 'Terraplanagem',
  estacaInicial: '1115',
  estacaFinal: '1120',
  servicoNotavel: 'COMPACTAÇÃO DE ATERRO',
  servicoNotavelDetalhe: 'Aterro na saia',
  quantidade: 12,
  unidade: 'm³',
  descricao: 'Aterro',
);

Registro _registroDe(String criadoEm, {String km = '225'}) => Registro(
      usuarioId: 1,
      trecho: 'C1',
      km: km,
      via: 'Via 02 Norte',
      atividade: 'Terraplanagem',
      estacaInicial: '1115',
      estacaFinal: '1120',
      servicoNotavel: 'COMPACTAÇÃO DE ATERRO',
      descricao: '',
      criadoEm: criadoEm,
    );

void main() {
  group('Lista de estacas', () {
    final lista = ListaDeEstacas(
        [estacaDe(1110, '224'), estacaDe(1115, '225'), estacaDe(1125, '226')],
        km: '225');

    test('estaca de outro KM aparece com o KM ao lado', () {
      expect(lista.rotulos, ['1110 (KM 224)', '1115', '1125 (KM 226)']);
      expect(lista.rotuloEscolhido('1125 (KM 226)'), '1125');
      expect(lista.rotuloNoCampo('1110'), '1110 (KM 224)');
      expect(lista.porRotulo('1115')?.km, '225');
      expect(lista.porRotulo('9999'), isNull);
    });

    test('a lista abre no KM escolhido; sem KM, não há onde abrir', () {
      expect(lista.indiceDoKm, 1);
      expect(lista.indiceDe('1125'), 2);
      final semKm = ListaDeEstacas(lista.estacas, usaKm: false);
      expect(semKm.rotulos, ['1110', '1115', '1125']);
      expect(semKm.indiceDoKm, isNull);
    });
  });

  group('Corrigir registro', () {
    late EditarRegistroViewModel vm;

    setUp(() async {
      vm = EditarRegistroViewModel(
        catalogo: CatalogoFalso(),
        estacas: EstacasFalsas(),
        original: _original,
      );
      await vm.carregar();
    });
    tearDown(() => vm.dispose());

    test('abre com o que foi gravado e as listas carregadas', () {
      expect(vm.carregando, isFalse);
      expect([vm.trecho, vm.km, vm.via, vm.estacaInicial],
          ['C1', '225', 'Via 02 Norte', '1115']);
      expect(vm.servicos, ['COMPACTAÇÃO DE ATERRO']);
      expect(vm.passos, ['Aterro na saia', 'Acabamento']);
      expect(vm.rotulosDasEstacas, hasLength(4));
      expect(vm.quantidadeInicial, '12');
    });

    test('salvar sem mudar nada não grava', () {
      expect(
          vm.salvar(
              textoQuantidade: vm.quantidadeInicial,
              descricao: vm.descricaoInicial),
          isA<SemMudanca>());
    });

    test('estaca final de outro KM: o KM final entra na correção', () {
      vm.escolherEstacaFinal('1125 (KM 226)');
      final resultado =
          vm.salvar(textoQuantidade: '12', descricao: 'Aterro') as Corrigido;
      expect(resultado.campos.estacaFinal, '1125');
      expect(resultado.campos.kmFinal, '226');
    });

    test('trocar o trecho zera o resto e pede o KM de novo', () async {
      await vm.escolherTrecho('PATIO DE VIGAS');
      expect([vm.km, vm.atividade, vm.servico], everyElement(isNull));
      expect(vm.atividades, ['Civil']);
      final resultado = vm.salvar(textoQuantidade: '', descricao: '');
      expect((resultado as CorrecaoInvalida).erro, 'Selecione o KM');
    });
  });

  group('Importar atividade anterior', () {
    late ImportarAtividadeViewModel vm;

    setUp(() async {
      final registros = RegistrosFalsos()
        ..anteriores = [
          _registroDe('2026-10-22T13:00:00.000Z'),
          _registroDe('2026-10-22T11:00:00.000Z', km: '226'),
          _registroDe('2026-10-20T13:00:00.000Z'),
        ];
      vm = ImportarAtividadeViewModel(registros: registros, usuarioId: 1);
      await vm.carregar();
    });

    test('lista os dias com registro, do mais novo', () {
      expect(vm.semRegistros, isFalse);
      expect(vm.dias.map((d) => d.day), [22, 20]);
      expect(vm.registros, hasLength(3));
    });

    test('filtrar por dia e voltar para todos', () {
      vm.filtrarPorDia(vm.dias.last);
      expect(vm.registros, hasLength(1));
      vm.filtrarPorDia(null);
      expect(vm.registros, hasLength(3));
    });

    test('título com trecho e KM; data do registro', () {
      final r = vm.registros.first;
      expect(vm.titulo(r), allOf(startsWith('C1 • '), contains('225')));
      expect(vm.data(r), '22/10/2026');
    });

    test('erro ao ler: para de girar e avisa', () async {
      final comErro = ImportarAtividadeViewModel(
          registros: RegistrosFalsos()..falharAoListar = true, usuarioId: 1);
      await comErro.carregar();
      expect(comErro.carregando, isFalse);
      expect(comErro.falhou, isTrue);
    });
  });
}
