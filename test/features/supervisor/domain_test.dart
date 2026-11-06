import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:namer_app/features/mapa/domain/entities/estaca_navegavel.dart';
import 'package:namer_app/features/registro/domain/entities/registro.dart';
import 'package:namer_app/features/relatorio/domain/entities/funcao_equipe.dart';
import 'package:namer_app/features/supervisor/domain/entities/clima_da_equipe.dart';
import 'package:namer_app/features/supervisor/domain/entities/resumo_do_encarregado.dart';
import 'package:namer_app/features/supervisor/domain/regras/avanco.dart';
import 'package:namer_app/features/supervisor/domain/regras/fotos_do_consolidado.dart';
import 'package:namer_app/features/supervisor/domain/usecases/baixar_fotos_do_consolidado.dart';
import 'package:namer_app/features/supervisor/domain/usecases/carregar_dia_da_equipe.dart';
import 'package:namer_app/features/supervisor/domain/usecases/registros_do_aparelho_no_dia.dart';

import '../registro/fakes.dart' as registro;
import 'fakes.dart';

void main() {
  group('Carregar o dia da equipe', () {
    late RegistrosFalsos repositorio;

    setUp(() => repositorio = RegistrosFalsos());

    test('junta registros, paradas, clima e efetivo de cada um, na ordem da equipe',
        () async {
      repositorio
        ..registros = [registroDaEquipe(ana.matricula, DateTime(2026, 9, 24, 8))]
        ..paradas = [
          parada(joao.matricula, DateTime(2026, 9, 24, 13),
              fim: DateTime(2026, 9, 24, 14))
        ]
        ..clima = {ana.matricula: const ClimaDaEquipe(manha: 'Bom')}
        ..efetivo = {
          ana.matricula: const [FuncaoEquipe(funcao: 'Servente', quantidade: 4)]
        };
      final resumos = await CarregarDiaDaEquipe(repositorio, ehNoturno: (_) => false)(
          [joao, ana], DateTime(2026, 9, 24));

      expect([for (final r in resumos) r.encarregado], [joao, ana]);
      expect(resumos[0].registros, isEmpty);
      expect(resumos[0].totalParado, const Duration(hours: 1));
      expect(resumos[1].registros, hasLength(1));
      expect(resumos[1].totalPessoas, 4);
      expect(resumos[1].clima?.linha, 'Manhã: Bom');
    });

    test('a madrugada de quem é da noite fica no dia anterior', () async {
      repositorio.registros = [
        registroDaEquipe(ana.matricula, DateTime(2026, 9, 25, 2)),
        registroDaEquipe(joao.matricula, DateTime(2026, 9, 25, 2), idLocal: 2),
      ];
      final resumos = await CarregarDiaDaEquipe(repositorio,
          ehNoturno: (m) => m == joao.matricula)([ana, joao], DateTime(2026, 9, 24));
      expect(resumos[0].registros, isEmpty);
      expect(resumos[1].registros, hasLength(1));
    });

    test('sem equipe, nem pergunta ao servidor', () async {
      expect(await CarregarDiaDaEquipe(repositorio, ehNoturno: (_) => false)(
              [], DateTime(2026, 9, 24)),
          isEmpty);
      expect(repositorio.janelasPedidas, isEmpty);
    });
  });

  group('Fotos do relatório da equipe', () {
    test('de cada encarregado: as dos registros e depois as das paradas', () {
      final r = registroDaEquipe(ana.matricula, DateTime(2026, 9, 24, 8),
          estacaInicial: 'EST. 1115');
      final p = parada(ana.matricula, DateTime(2026, 9, 24, 13, 10));
      final fotos = fotosDoConsolidado([
        ResumoDoEncarregado(
            encarregado: ana, registros: [r], efetivo: const [], paralisacoes: [p]),
        ResumoDoEncarregado(encarregado: joao, registros: const [], efetivo: const []),
      ], caminhosDosRegistros: {
        r.chave: ['a.jpg', 'b.jpg']
      }, caminhosDasParadas: {
        p.chave: ['c.jpg']
      });

      expect([for (final f in fotos) f.caminho], ['a.jpg', 'b.jpg', 'c.jpg']);
      expect(fotos.every((f) => f.encarregado == 0), isTrue);
      expect(fotos.first.legenda, 'COMPACTAÇÃO DE ATERRO - estaca EST. 1115');
      expect(fotos.last.legenda, 'Paralisação - Chuva - 13:10');
    });

    test('baixa em lotes, avisa o progresso e deixa de fora a que falha',
        () async {
      final r1 = registroDaEquipe(ana.matricula, DateTime(2026, 9, 24, 8));
      final r2 =
          registroDaEquipe(joao.matricula, DateTime(2026, 9, 24, 9), idLocal: 2);
      final repositorio = RegistrosFalsos()
        ..fotosDosRegistros = {
          r1.chave: ['1.jpg', '2.jpg', '3.jpg'],
          r2.chave: ['4.jpg'],
        }
        ..arquivos = {
          for (final c in ['1.jpg', '2.jpg', '4.jpg']) c: Uint8List.fromList([1]),
        };
      final progresso = <String>[];

      final fotos = await BaixarFotosDoConsolidado(repositorio)([
        ResumoDoEncarregado(encarregado: ana, registros: [r1], efetivo: const []),
        ResumoDoEncarregado(encarregado: joao, registros: [r2], efetivo: const []),
      ], simultaneas: 2, aoProgredir: (b, t) => progresso.add('$b/$t'));

      expect(progresso, ['0/4', '2/4', '4/4']);
      expect(repositorio.downloads, 4);
      expect(fotos[0], hasLength(2)); // a 3.jpg falhou
      expect(fotos[1], hasLength(1));
    });
  });

  test('do aparelho: só o dia de trabalho, sem o lançado por outro, em ordem',
      () async {
    Registro doAparelho(int id, DateTime quando, {String emNomeDe = ''}) => Registro(
          id: id,
          usuarioId: 1,
          trecho: 'C1',
          km: '225',
          via: '',
          atividade: 'Terraplenagem',
          estacaInicial: 'EST. 1115',
          estacaFinal: 'EST. 1115',
          servicoNotavel: 'COMPACTAÇÃO DE ATERRO',
          emNomeDeMatricula: emNomeDe,
          descricao: '',
          criadoEm: quando.toUtc().toIso8601String(),
        );
    final aparelho = registro.RegistrosFalsos()
      ..anteriores = [
        doAparelho(3, DateTime(2026, 9, 25, 2)), // madrugada: noite do 24
        doAparelho(2, DateTime(2026, 9, 24, 20)),
        doAparelho(1, DateTime(2026, 9, 24, 9), emNomeDe: '045020'),
        doAparelho(4, DateTime(2026, 9, 23, 20)),
      ];
    var noturno = true;
    final doDia = RegistrosDoAparelhoNoDia(aparelho,
        usuarioId: 1, nome: 'Ana', matricula: '051395', noturno: () => noturno);

    final daNoite = await doDia(DateTime(2026, 9, 24));
    expect([for (final r in daNoite) r.idLocal], [2, 3]);
    expect(daNoite.first.usuarioMatricula, '051395');

    noturno = false;
    expect([for (final r in await doDia(DateTime(2026, 9, 24))) r.idLocal], [2]);
  });

  test('eixo do projeto: uma linha por trecho e pista, com pelo menos 2 pontos',
      () {
    EstacaNavegavel estaca(String trecho, int n, String? via) => EstacaNavegavel(
          trecho: trecho,
          km: '225',
          rotulo: 'EST. $n',
          numero: n,
          ponto: LatLng(-19.9 + n * 0.0002, -40.4),
          via: via,
        );
    final estacas = agruparEstacasPorTrecho([
      estaca('C1', 1100, 'Via 01 Sul'),
      estaca('C1', 1101, 'Via 01 Sul'),
      estaca('C1', 1100, 'Via 02 Norte'),
      estaca('C1', 1101, 'Via 02 Norte'),
      estaca('D2', 2000, null), // uma estaca só: não vira linha
    ]);
    expect(eixosPorPista(estacas), hasLength(2));
    expect(eixosPorPista(estacas, trechos: ['D2']), isEmpty);
  });
}
