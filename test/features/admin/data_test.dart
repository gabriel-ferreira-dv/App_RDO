import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:namer_app/features/registro/domain/entities/campos_do_registro.dart';
import 'package:namer_app/features/supervisor/domain/entities/registro_da_equipe.dart';

import 'fakes.dart';

void main() {
  late RemotoFalso remoto;
  late LocalFalso local;
  late Map<String, List<String>> caminhos;
  late List<RegistroDaEquipe> corrigidosNoServidor;
  late AdminRepositoryImpl repositorio;

  setUp(() {
    remoto = RemotoFalso();
    local = LocalFalso();
    caminhos = {};
    corrigidosNoServidor = [];
    repositorio = AdminRepositoryImpl(
      remoto: remoto,
      local: local,
      // A matrícula 999 é do turno da noite.
      ehNoturno: (matricula) => matricula == '999',
      caminhosDasFotos: (_) async => caminhos,
      corrigirNoServidor: (r, _) async {
        corrigidosNoServidor.add(r);
        return null;
      },
    );
  });

  Map<String, dynamic> linha(String matricula, DateTime criadoEm) => {
        'dispositivo_id': 'a',
        'id_local': criadoEm.hour,
        'usuario_nome': 'U$matricula',
        'usuario_matricula': matricula,
        'criado_em': criadoEm.toUtc().toIso8601String(),
      };

  group('Sou admin?', () {
    test('com internet: pergunta e guarda a resposta', () async {
      remoto.admin = true;
      expect(await repositorio.souAdmin(), isTrue);
      expect(local.guardado, isTrue);
    });

    test('sem internet: a última resposta; sem nenhuma, não', () async {
      remoto.falhar = true;
      expect(await repositorio.souAdmin(), isFalse);
      local.guardado = true;
      expect(await repositorio.souAdmin(), isTrue);
    });
  });

  group('Registros do dia', () {
    test('a madrugada só conta no dia anterior para quem é da noite', () async {
      remoto.linhas = [
        linha('051395', DateTime(2026, 10, 15, 9)),
        linha('999', DateTime(2026, 10, 16, 2)),
        linha('051395', DateTime(2026, 10, 16, 2)),
      ];
      final registros =
          await repositorio.registrosDoDia(DateTime(2026, 10, 15, 18));
      expect(
          [for (final r in registros!) r.usuarioMatricula], ['051395', '999']);
    });

    test('sem internet: null (a tela avisa)', () async {
      remoto.falhar = true;
      expect(await repositorio.registrosDoDia(DateTime(2026, 10, 15)), isNull);
    });
  });

  group('Endereços das fotos', () {
    final registros = [registroDe('Ana', '1', 1), registroDe('Bia', '2', 2)];

    test('troca cada caminho pelo endereço; o que falhou fica de fora',
        () async {
      caminhos = {
        'aparelho|1': ['010152/ana/a.jpg', '010152/ana/b.jpg'],
        'aparelho|2': ['010152/bia/c.jpg'],
      };
      remoto.enderecos = {
        '010152/ana/a.jpg': 'https://a',
        '010152/bia/c.jpg': 'https://c',
      };
      expect(await repositorio.enderecosDasFotos(registros), {
        'aparelho|1': ['https://a'],
        'aparelho|2': ['https://c'],
      });
    });

    test('sem fotos, nem pergunta ao servidor; sem internet, vazio', () async {
      expect(await repositorio.enderecosDasFotos(registros), isEmpty);
      expect(remoto.pedidosDeEndereco, isEmpty);

      caminhos = {
        'aparelho|1': ['x.jpg']
      };
      remoto.falhar = true;
      expect(await repositorio.enderecosDasFotos(registros), isEmpty);
    });
  });

  test('corrigir vai para o servidor', () async {
    final r = registroDe('Ana', '1', 1);
    expect(
        await repositorio.corrigir(
            r,
            const CamposDoRegistro(
                trecho: 'C1', km: '1', atividade: 'a', servicoNotavel: 's')),
        isNull);
    expect(corrigidosNoServidor, [r]);
  });
}
