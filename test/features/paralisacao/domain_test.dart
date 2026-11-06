import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/paralisacao/domain/entities/paralisacao.dart';
import 'package:namer_app/features/paralisacao/domain/entities/resumo_das_paralisacoes.dart';
import 'package:namer_app/features/paralisacao/domain/usecases/carregar_paralisacoes_do_dia.dart';
import 'package:namer_app/features/paralisacao/domain/usecases/esta_parado_agora.dart';
import 'package:namer_app/features/paralisacao/domain/usecases/retomar_servico.dart';
import 'package:namer_app/features/paralisacao/domain/usecases/salvar_paralisacao.dart';

import 'fakes.dart';

void main() {
  group('descreverParalisacao', () {
    test('encerrada: horário, duração, motivo, local e observação', () {
      expect(
        descreverParalisacao(
          inicio: DateTime(2026, 9, 24, 13, 10),
          fim: DateTime(2026, 9, 24, 15, 40),
          motivo: 'Chuva',
          trecho: 'C1',
          km: '225',
          observacao: 'pista alagada',
        ),
        '13:10 às 15:40 (2h30) - Chuva - C1 / KM 225 - pista alagada',
      );
    });

    test('ainda parado: sem término', () {
      expect(
        descreverParalisacao(
            inicio: DateTime(2026, 9, 24, 13, 10), motivo: 'Falta de material'),
        '13:10 - sem término - Falta de material',
      );
    });

    // Local e observação são opcionais: não pode sobrar separador.
    test('sem local nem observação não deixa traço solto', () {
      expect(
        descreverParalisacao(
          inicio: DateTime(2026, 9, 24, 8),
          fim: DateTime(2026, 9, 24, 8, 45),
          motivo: 'Chuva',
          trecho: ' ',
          observacao: '',
        ),
        '08:00 às 08:45 (45 min) - Chuva',
      );
    });

    test('turno da noite: atravessa a meia-noite', () {
      expect(
        descreverParalisacao(
          inicio: DateTime(2026, 9, 24, 22, 30),
          fim: DateTime(2026, 9, 25, 1),
          motivo: 'Chuva',
        ),
        startsWith('22:30 às 01:00 (2h30)'),
      );
    });

    // A fonte do PDF só desenha Latin-1: travessão ou "•" virariam quadradinho.
    test('cabe no Latin-1 do PDF', () {
      final texto = descreverParalisacao(
        inicio: DateTime(2026, 9, 24, 13, 10),
        fim: DateTime(2026, 9, 24, 15, 40),
        motivo: 'Equipamento quebrado',
        trecho: 'CONTORNO DE FUNDÃO',
        km: '203',
      );
      expect(texto.runes.where((r) => r > 0xFF), isEmpty, reason: texto);
    });
  });

  test('formatarDuracao', () {
    expect(formatarDuracao(const Duration(minutes: 45)), '45 min');
    expect(formatarDuracao(const Duration(hours: 2)), '2h');
    expect(formatarDuracao(const Duration(hours: 2, minutes: 5)), '2h05');
  });

  test('tempoParado soma só as encerradas', () {
    final total = tempoParado([
      (inicio: DateTime(2026, 9, 24, 8), fim: DateTime(2026, 9, 24, 9)),
      (inicio: DateTime(2026, 9, 24, 13), fim: DateTime(2026, 9, 24, 13, 30)),
      (inicio: DateTime(2026, 9, 24, 16), fim: null),
    ]);
    expect(total, const Duration(hours: 1, minutes: 30));
  });

  // Quem é da noite: a parada da madrugada conta no dia em que o turno começou.
  test('madrugada do turno da noite fica no dia anterior', () {
    final madrugada = parada(inicio: DateTime(2026, 9, 25, 1, 30));
    expect(madrugada.diaDeTrabalho(noturno: true), DateTime(2026, 9, 24));
    expect(madrugada.diaDeTrabalho(noturno: false), DateTime(2026, 9, 25));
  });

  test('local e observação numa linha', () {
    expect(
        parada(inicio: agoraDeTeste, trecho: 'C1', km: '225', observacao: 'x')
            .localEObservacao,
        'C1 / KM 225 · x');
    expect(parada(inicio: agoraDeTeste, trecho: 'D2').localEObservacao, 'D2');
    expect(parada(inicio: agoraDeTeste).localEObservacao, '');
  });

  test('os motivos cobrem chuva e o "Outro"', () {
    expect(motivosParalisacao.first, 'Chuva');
    expect(motivosParalisacao, contains('Outro'));
  });

  group('Regras para salvar', () {
    final inicio = DateTime(2026, 9, 24, 13);

    test('precisa de motivo', () {
      expect(problemaDaParalisacao(motivo: null, inicio: inicio),
          'Escolha o motivo da paralisação');
      expect(problemaDaParalisacao(motivo: ' ', inicio: inicio),
          'Escolha o motivo da paralisação');
    });

    test('o término vem depois do início', () {
      expect(
          problemaDaParalisacao(motivo: 'Chuva', inicio: inicio, fim: inicio),
          'O término tem que ser depois do início');
      expect(
          problemaDaParalisacao(
              motivo: 'Chuva',
              inicio: inicio,
              fim: inicio.add(const Duration(minutes: 1))),
          isNull);
    });
  });

  test('resumo separa em andamento e encerradas e soma o tempo parado', () {
    final resumo = ResumoDasParalisacoes([
      parada(
          id: 1,
          inicio: DateTime(2026, 9, 24, 8),
          fim: DateTime(2026, 9, 24, 9)),
      parada(id: 2, inicio: DateTime(2026, 9, 24, 14)),
    ], {
      1: 3
    });
    expect(resumo.encerradas.map((p) => p.id), [1]);
    expect(resumo.emAndamento.map((p) => p.id), [2]);
    expect(resumo.totalParado, const Duration(hours: 1));
    expect(resumo.fotosDe(resumo.encerradas.first), 3);
    expect(resumo.fotosDe(resumo.emAndamento.first), 0);
    expect(ResumoDasParalisacoes.nenhuma.semParalisacoes, isTrue);
  });

  group('Casos de uso', () {
    late RepositorioFalso repositorio;
    setUp(() => repositorio = RepositorioFalso());

    test('salvar sem motivo não grava nada', () async {
      final resultado = await SalvarParalisacao(repositorio)(
        usuarioId: 1,
        motivo: null,
        inicio: agoraDeTeste,
        criadoEm: '',
      );
      expect(resultado, isA<NaoSalvou>());
      expect(repositorio.paralisacoes, isEmpty);
    });

    test('salvar grava em UTC, sem espaços na observação', () async {
      final resultado = await SalvarParalisacao(repositorio)(
        usuarioId: 1,
        motivo: 'Chuva',
        inicio: agoraDeTeste,
        observacao: '  pista alagada ',
        criadoEm: '',
      );
      expect((resultado as Salvou).id, 1);
      final gravada = repositorio.paralisacoes.single;
      expect(gravada.inicio.isUtc, isTrue);
      expect(gravada.inicio, agoraDeTeste.toUtc());
      expect(gravada.observacao, 'pista alagada');
    });

    test('carregar o dia junta a lista e as fotos', () async {
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 24, 8)));
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 23, 8)));
      await repositorio.adicionarFoto(
          paralisacaoId: 1, caminhoArquivo: 'a.jpg', quando: agoraDeTeste);

      final resumo = await CarregarParalisacoesDoDia(repositorio)(
          1, DateTime(2026, 9, 24),
          noturno: false);
      expect(resumo.lista.map((p) => p.id), [1]);
      expect(resumo.fotosDe(resumo.lista.single), 1);
    });

    test('retomar fecha agora e diz quanto ficou parado', () async {
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 24, 13)));
      final parado = await RetomarServico(repositorio,
          agora: () => agoraDeTeste)(repositorio.paralisacoes.single);
      expect(parado, const Duration(hours: 2));
      expect(repositorio.paralisacoes.single.fim, agoraDeTeste.toUtc());
    });

    test('parado agora: só com paralisação aberta no dia do turno', () async {
      final estaParado =
          EstaParadoAgora(repositorio, agora: () => agoraDeTeste);
      expect(await estaParado(1, noturno: false), isFalse);

      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 24, 14)));
      expect(await estaParado(1, noturno: false), isTrue);

      await repositorio.encerrar(1, agoraDeTeste);
      expect(await estaParado(1, noturno: false), isFalse);
    });

    test('turno da noite: às 2h ainda vale a parada da noite anterior',
        () async {
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 24, 23)));
      final madrugada = DateTime(2026, 9, 25, 2);
      expect(
          await EstaParadoAgora(repositorio, agora: () => madrugada)(1,
              noturno: true),
          isTrue);
      expect(
          await EstaParadoAgora(repositorio, agora: () => madrugada)(1,
              noturno: false),
          isFalse);
    });
  });
}
