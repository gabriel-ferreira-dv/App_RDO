import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/supervisor/data/datasources/registros_equipe_supabase.dart';
import 'package:namer_app/features/supervisor/data/repositories/equipe_repository_impl.dart';
import 'package:namer_app/features/supervisor/data/repositories/registros_da_equipe_repository_impl.dart';

import 'fakes.dart';

Map<String, dynamic> _linhaDeRegistro(int id) => {
      'dispositivo_id': 'aparelho-1',
      'id_local': id,
      'usuario_matricula': '051395',
      'criado_em': DateTime(2026, 9, 24, 8).toUtc().toIso8601String(),
    };

void main() {
  late RemotoFalso remoto;
  late RegistrosDaEquipeRepositoryImpl repositorio;

  setUp(() {
    remoto = RemotoFalso();
    repositorio = RegistrosDaEquipeRepositoryImpl(
        remoto: remoto, efetivoDoDia: (_) async => {});
  });

  group('Registros da equipe', () {
    test('caminhos das fotos: só dos registros pedidos e com arquivo', () async {
      final r1 = registroDaEquipe('051395', DateTime(2026, 9, 24, 8), idLocal: 1);
      final r2 = registroDaEquipe('051395', DateTime(2026, 9, 24, 9),
          idLocal: 2, dispositivo: 'aparelho-2');
      remoto.linhasDeFotos = [
        {'dispositivo_id': 'aparelho-1', 'registro_id_local': 1, 'caminho_storage': 'a.jpg'},
        // aparelho-1|2 não foi pedido: veio porque a busca filtra os dois
        // campos separados.
        {'dispositivo_id': 'aparelho-1', 'registro_id_local': 2, 'caminho_storage': 'x.jpg'},
        {'dispositivo_id': 'aparelho-2', 'registro_id_local': 2, 'caminho_storage': ''},
      ];
      expect(await repositorio.caminhosDasFotos([r1, r2]), {
        'aparelho-1|1': ['a.jpg'],
      });
    });

    test('sem registro, nem pergunta; sem internet, vazio', () async {
      expect(await repositorio.caminhosDasFotos([]), isEmpty);
      remoto.falhar = true;
      expect(
          await repositorio
              .caminhosDasFotos([registroDaEquipe('051395', DateTime(2026, 9, 24))]),
          isEmpty);
    });

    test('o período vem em páginas até a última incompleta', () async {
      remoto.paginas = [
        [for (var i = 0; i < RegistrosEquipeSupabase.pagina; i++) _linhaDeRegistro(i)],
        [_linhaDeRegistro(9999)],
      ];
      final registros = await repositorio.registrosDoPeriodo(['051395']);
      expect(registros, hasLength(RegistrosEquipeSupabase.pagina + 1));
      expect(remoto.paginasPedidas, [0, RegistrosEquipeSupabase.pagina]);
    });

    test('o período sem internet volta null (a tela avisa)', () async {
      remoto.falhar = true;
      expect(await repositorio.registrosDoPeriodo(['051395']), isNull);
    });

    test('corrigir: sem linha alterada é falta de permissão', () async {
      final r = registroDaEquipe('051395', DateTime(2026, 9, 24));
      expect(await repositorio.corrigir(r, r.campos),
          'Sem permissão para corrigir este registro');
      remoto.alteradas = [
        {'id': 1}
      ];
      expect(await repositorio.corrigir(r, r.campos), isNull);
      remoto.falhar = true;
      expect(await repositorio.corrigir(r, r.campos), contains('internet'));
    });
  });

  group('Equipe', () {
    late EquipeRemotaFalsa remota;
    late EquipeRepositoryImpl equipe;

    setUp(() {
      remota = EquipeRemotaFalsa();
      equipe = EquipeRepositoryImpl(
        remota: remota,
        encarregadosDoApontamento: () async =>
            [(matricula: '045020', nome: 'João Souza')],
      );
    });

    test('salva a lista inteira; sem matrícula ou sem internet, avisa', () async {
      expect(await equipe.salvarEquipe(' 9001 ', [ana]), isNull);
      expect(remota.trocas['9001'], [
        {'encarregado_matricula': '051395', 'encarregado_nome': 'Ana Lima'}
      ]);
      expect(await equipe.salvarEquipe('', [ana]),
          'Supervisor sem matrícula cadastrada');
      remota.falhar = true;
      expect(await equipe.salvarEquipe('9001', [ana]), contains('conexão'));
    });

    test('carrega a equipe; sem internet, vazia', () async {
      remota.linhas = [
        {'encarregado_matricula': '051395', 'encarregado_nome': 'Ana Lima'}
      ];
      expect(await equipe.equipeDe('9001'), [ana]);
      remota.falhar = true;
      expect(await equipe.equipeDe('9001'), isEmpty);
      expect(await equipe.encarregadosRecentes(), [joao]);
    });
  });
}
