import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/paralisacao/data/models/paralisacao_model.dart';
import 'package:namer_app/features/paralisacao/data/repositories/paralisacao_repository_impl.dart';

import 'fakes.dart';

void main() {
  group('Modelo', () {
    final base = parada(
      id: 3,
      motivo: 'Chuva',
      observacao: 'forte',
      trecho: 'D2',
      km: '231',
      inicio: DateTime.utc(2026, 9, 24, 16, 10),
    );

    test('ida e volta pelo banco, ainda parada', () {
      final volta = paralisacaoDoMapa(base.paraMapa());
      expect(volta.motivo, 'Chuva');
      expect(volta.km, '231');
      expect(volta.inicio, base.inicio);
      expect(volta.fim, isNull);
      expect(volta.emAndamento, isTrue);
    });

    test('ida e volta pelo banco, encerrada', () {
      final encerrada = paralisacaoDoMapa({
        ...base.paraMapa(),
        'fim': DateTime.utc(2026, 9, 24, 18).toIso8601String(),
      });
      expect(encerrada.fim, DateTime.utc(2026, 9, 24, 18));
      expect(encerrada.emAndamento, isFalse);
    });

    test('campos de texto nulos viram vazios', () {
      final p = paralisacaoDoMapa({
        ...base.paraMapa(),
        'observacao': null,
        'trecho': null,
        'km': null,
      });
      expect([p.observacao, p.trecho, p.km], ['', '', '']);
    });
  });

  group('Repositório', () {
    late BancoFalso banco;
    late ParalisacaoRepositoryImpl repositorio;

    setUp(() {
      banco = BancoFalso();
      repositorio = ParalisacaoRepositoryImpl(banco);
    });

    test('salvar nova: sem id e pendente de envio', () async {
      final id = await repositorio.salvar(parada(inicio: agoraDeTeste));
      expect(id, 1);
      expect(banco.linhas.single['sincronizado'], 0);
      expect(banco.linhas.single['motivo'], 'Chuva');
    });

    test('editar, encerrar e excluir marcam pendente de novo', () async {
      final id = await repositorio.salvar(parada(inicio: agoraDeTeste));
      banco.linhas.single['sincronizado'] = 1;

      await repositorio
          .salvar(parada(id: id, motivo: 'Segurança', inicio: agoraDeTeste));
      expect(banco.linhas.single['motivo'], 'Segurança');
      expect(banco.linhas.single['sincronizado'], 0);

      banco.linhas.single['sincronizado'] = 1;
      await repositorio.encerrar(id, DateTime.utc(2026, 9, 24, 18));
      expect(banco.linhas.single['fim'], '2026-09-24T18:00:00.000Z');
      expect(banco.linhas.single['sincronizado'], 0);

      await repositorio.excluir(id);
      expect(banco.linhas.single['excluida'], 1);
      expect(
          await repositorio.listarDoDia(1, DateTime(2026, 9, 24),
              noturno: false),
          isEmpty);
    });

    test('dia de trabalho respeita o turno da noite', () async {
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 24, 22)));
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 25, 1, 30)));
      // Depois do meio-dia: já é o dia 25 até para quem é da noite.
      await repositorio.salvar(parada(inicio: DateTime(2026, 9, 25, 13)));

      Future<List<int?>> ids(DateTime dia, bool noturno) async => [
            for (final p
                in await repositorio.listarDoDia(1, dia, noturno: noturno))
              p.id,
          ];
      expect(await ids(DateTime(2026, 9, 24), true), [1, 2]);
      expect(await ids(DateTime(2026, 9, 24), false), [1]);
      expect(await ids(DateTime(2026, 9, 25), false), [2, 3]);
    });

    test('fotos: grava, lista e conta; sem ids nem consulta', () async {
      await repositorio.adicionarFoto(
          paralisacaoId: 7,
          caminhoArquivo: 'a.jpg',
          latitude: -19.9,
          longitude: -40.3,
          quando: agoraDeTeste);
      await repositorio.adicionarFoto(
          paralisacaoId: 7, caminhoArquivo: 'b.jpg', quando: agoraDeTeste);

      expect((await repositorio.fotosDe(7)).map((f) => f.caminhoArquivo),
          ['a.jpg', 'b.jpg']);
      expect(await repositorio.contarFotos([7, 8]), {7: 2});
      expect(await repositorio.contarFotos([]), isEmpty);
      expect(banco.consultasDeFotos, 1);
    });

    test('último local: trecho e KM do registro, nulos viram vazio', () async {
      expect(
          await repositorio.ultimoLocalDesde(1, DateTime(2026, 9, 24)), isNull);
      banco.ultimoRegistro = {'trecho': 'C1', 'km': null};
      final local =
          await repositorio.ultimoLocalDesde(1, DateTime(2026, 9, 24));
      expect(local, (trecho: 'C1', km: ''));
      expect(
          banco.desdePedido, DateTime(2026, 9, 24).toUtc().toIso8601String());
    });
  });
}
