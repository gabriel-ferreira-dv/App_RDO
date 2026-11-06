import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/inicio/inicio_service.dart';
import 'package:namer_app/features/inicio/presentation/widgets/menu_da_conta.dart';
import 'package:namer_app/features/paralisacao/domain/entities/paralisacao.dart';
import 'package:namer_app/features/registro/domain/entities/grupo_atividade.dart';

RegistroAgrupado _registro(int id, DateTime criadoEm, int fotos) =>
    RegistroAgrupado(
      registroId: id,
      via: '',
      estacaInicial: '1115',
      estacaFinal: '1120',
      descricao: '',
      criadoEm: criadoEm.toUtc().toIso8601String(),
      fotos: [
        for (var i = 0; i < fotos; i++)
          FotoAgrupada(
            fotoId: id * 10 + i,
            caminhoArquivo: 'f.jpg',
            criadoEm: criadoEm.toUtc().toIso8601String(),
          ),
      ],
    );

Paralisacao _parada(DateTime inicio, [DateTime? fim]) => Paralisacao(
      usuarioId: 1,
      motivo: 'Chuva',
      inicio: inicio.toUtc(),
      fim: fim?.toUtc(),
      criadoEm: inicio.toUtc().toIso8601String(),
    );

void main() {
  final agora = DateTime(2026, 10, 15, 11);
  final hoje = DateTime(2026, 10, 15);
  final grupos = [
    GrupoAtividade(
      trecho: 'C1',
      km: '225',
      atividade: 'Terraplanagem',
      servicoNotavel: 'X',
      registros: [
        _registro(1, DateTime(2026, 10, 15, 7, 30), 3),
        _registro(2, DateTime(2026, 10, 15, 9), 2),
        // Ontem à noite: no turno do dia, fica fora; no da noite, também.
        _registro(3, DateTime(2026, 10, 14, 20), 4),
      ],
    ),
  ];

  test('conta os registros e as fotos do dia', () {
    final r = montarResumoDoDia(
        grupos: grupos, paradas: [], dia: hoje, noturno: false, agora: agora);
    expect(r.registros, 2);
    expect(r.fotos, 5);
    expect(r.paradoAgora, isFalse);
  });

  test('no turno da noite, o que foi feito antes do meio-dia é do dia anterior',
      () {
    final r = montarResumoDoDia(
      grupos: grupos,
      paradas: [],
      dia: DateTime(2026, 10, 14),
      noturno: true,
      agora: agora,
    );
    // 20h de ontem, 7h30 e 9h de hoje: tudo antes do meio-dia de hoje.
    expect(r.registros, 3);
  });

  test('soma o tempo parado e acha a parada aberta', () {
    final r = montarResumoDoDia(
      grupos: [],
      paradas: [
        _parada(DateTime(2026, 10, 15, 8), DateTime(2026, 10, 15, 8, 40)),
        _parada(DateTime(2026, 10, 15, 10, 30)),
      ],
      dia: hoje,
      noturno: false,
      agora: agora,
    );
    expect(r.paradas, 2);
    expect(r.paradoAgora, isTrue);
    expect(r.tempoParado, const Duration(hours: 1, minutes: 10));
  });

  test('saudação pela hora', () {
    expect(saudacao(DateTime(2026, 10, 15, 6)), 'Bom dia');
    expect(saudacao(DateTime(2026, 10, 15, 13)), 'Boa tarde');
    expect(saudacao(DateTime(2026, 10, 15, 21)), 'Boa noite');
    expect(saudacao(DateTime(2026, 10, 15, 2)), 'Boa noite');
  });

  test('iniciais do usuário na barra do topo', () {
    expect(MenuDaConta.iniciais('Gabriel Souza'), 'GS');
    expect(MenuDaConta.iniciais('  maria  da silva '), 'MS');
    expect(MenuDaConta.iniciais('Joao'), 'J');
    expect(MenuDaConta.iniciais(''), '?');
  });
}
