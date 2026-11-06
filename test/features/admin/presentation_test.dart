import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/admin/domain/usecases/carregar_registros_dos_usuarios.dart';
import 'package:namer_app/features/admin/presentation/pages/registros_dos_usuarios_page.dart';
import 'package:namer_app/features/admin/presentation/viewmodels/registros_dos_usuarios_view_model.dart';
import 'package:namer_app/features/registro/domain/entities/campos_do_registro.dart';

import 'fakes.dart';

final _hoje = DateTime(2026, 10, 15);
const _campos = CamposDoRegistro(
    trecho: 'C1', km: '225', atividade: 'Civil', servicoNotavel: 'ANDAIME');

RegistrosDosUsuariosViewModel _vm(RepositorioFalso repositorio) =>
    RegistrosDosUsuariosViewModel(
      carregarDoDia: CarregarRegistrosDosUsuarios(repositorio),
      repositorio: repositorio,
      agora: () => DateTime(2026, 10, 15, 16),
    );

void main() {
  late RepositorioFalso repositorio;

  setUp(() {
    repositorio = RepositorioFalso()
      ..registrosPorDia[_hoje] = [
        registroDe('Ítalo Souza', '051395', 1),
        registroDe('Ana Lima', '064925', 2),
        registroDe('Ítalo Souza', '051395', 3),
      ];
  });

  group('ViewModel', () {
    test('carrega o dia de hoje e resume', () async {
      final vm = _vm(repositorio);
      expect(vm.dia, _hoje);
      expect(vm.situacao, SituacaoDaLista.carregando);
      await vm.carregar();
      expect(vm.situacao, SituacaoDaLista.pronta);
      expect(vm.resumo, '3 registros de 2 usuários');
      expect(vm.resumoDe(vm.grupos.last), '051395 · 2 registros');
    });

    test('a busca filtra; sem ninguém, explica', () async {
      final vm = _vm(repositorio);
      await vm.carregar();
      vm.definirBusca('ana');
      expect(vm.grupos.single.nome, 'Ana Lima');
      expect(vm.resumo, '1 registro de 1 usuário');

      vm.definirBusca('zé');
      expect(vm.situacao, SituacaoDaLista.vazia);
      expect(vm.detalheDaListaVazia, 'Ninguém com esse nome ou matrícula.');
    });

    // Agrupar até 1000 registros custa: a tela lê grupos, situação e resumo
    // a cada desenho, e a conta só pode ser refeita quando algo muda.
    test('os grupos são calculados uma vez por mudança', () async {
      final vm = _vm(repositorio);
      await vm.carregar();
      final grupos = vm.grupos;
      expect(vm.situacao, SituacaoDaLista.pronta);
      expect(vm.resumo, '3 registros de 2 usuários');
      expect(vm.grupos, same(grupos));

      var avisos = 0;
      vm.addListener(() => avisos++);
      vm.definirBusca('');
      expect(avisos, 0);
      expect(vm.grupos, same(grupos));

      vm.definirBusca('ana');
      expect(avisos, 1);
      expect(vm.grupos, isNot(same(grupos)));
      expect(vm.grupos.single.nome, 'Ana Lima');
    });

    test('busca falhou: situação de falha', () async {
      repositorio.registrosPorDia[_hoje] = null;
      final vm = _vm(repositorio);
      await vm.carregar();
      expect(vm.situacao, SituacaoDaLista.falhou);
    });

    test('trocar de dia no meio da busca: fica a mais nova', () async {
      final ontem = DateTime(2026, 10, 14);
      repositorio.registrosPorDia[ontem] = [registroDe('Bia', '7', 9)];
      final vm = _vm(repositorio);
      final primeira = vm.carregar();
      vm.mudarDia(ontem);
      await primeira;
      await Future<void>.delayed(Duration.zero);
      expect(vm.dia, ontem);
      expect(vm.grupos.single.nome, 'Bia');
    });

    test('corrigir: deu certo avisa e recarrega; falhou mostra o erro',
        () async {
      final vm = _vm(repositorio);
      await vm.carregar();
      final alvo = vm.grupos.first.registros.first;

      expect(await vm.corrigir(alvo, _campos),
          startsWith('Registro corrigido. A foto ganha o carimbo novo'));
      expect(repositorio.corrigidos, [alvo]);

      repositorio.erroAoCorrigir = 'Sem permissão';
      expect(await vm.corrigir(alvo, _campos), 'Sem permissão');
      expect(vm.subtituloDaCorrecao(alvo), 'De Ana Lima, 14:12');
    });
  });

  testWidgets('tela: agrupa por usuário e a busca filtra', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home:
          Scaffold(body: RegistrosDosUsuariosPage(viewModel: _vm(repositorio))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('3 registros de 2 usuários'), findsOneWidget);
    expect(find.text('Ana Lima'), findsOneWidget);
    expect(find.text('Ítalo Souza'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'italo');
    await tester.pump();
    expect(find.text('Ana Lima'), findsNothing);
    expect(find.text('Ítalo Souza'), findsOneWidget);
  });
}
