import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/admin/domain/entities/registros_do_usuario.dart';
import 'package:namer_app/features/admin/domain/usecases/carregar_registros_dos_usuarios.dart';
import 'package:namer_app/features/admin/presentation/widgets/cartao_registro_do_usuario.dart';

import 'fakes.dart';

void main() {
  final registros = [
    registroDe('Ítalo Souza', '051395', 1),
    registroDe('Ana Lima', '064925', 2),
    registroDe('Ítalo Souza', '051395', 3),
  ];

  test('agrupa por usuário, em ordem alfabética', () {
    final grupos = agruparPorUsuario(registros);
    expect([for (final g in grupos) g.nome], ['Ana Lima', 'Ítalo Souza']);
    expect(grupos.last.registros.map((r) => r.idLocal), [1, 3]);
  });

  test('a busca acha pelo nome sem acento ou pela matrícula', () {
    expect(agruparPorUsuario(registros, busca: 'ITALO').single.matricula,
        '051395');
    expect(agruparPorUsuario(registros, busca: '0649').single.nome, 'Ana Lima');
    expect(agruparPorUsuario(registros, busca: 'zé'), isEmpty);
  });

  test('a linha de local e hora do cartão', () {
    expect(CartaoRegistroDoUsuario.localEHora(registros.first),
        'C1 · est. 2245 – 2247 · 14:12');
    expect(
        CartaoRegistroDoUsuario.localEHora(
            registroDe('X', '1', 9, estacaInicial: '', estacaFinal: '')),
        'C1 · km 225 · 14:12');
  });

  group('Carregar os registros do dia', () {
    final dia = DateTime(2026, 10, 15);

    test('com registros, busca as fotos', () async {
      final repositorio = RepositorioFalso()
        ..registrosPorDia[dia] = registros
        ..fotos = {
          'aparelho|1': ['https://foto/1']
        };
      final resultado = await CarregarRegistrosDosUsuarios(repositorio)(dia);
      expect(resultado.registros, hasLength(3));
      expect(resultado.fotos['aparelho|1'], ['https://foto/1']);
    });

    test('busca falhou: sem fotos e sem pedir fotos', () async {
      final repositorio = RepositorioFalso()..registrosPorDia[dia] = null;
      final resultado = await CarregarRegistrosDosUsuarios(repositorio)(dia);
      expect(resultado.registros, isNull);
      expect(resultado.fotos, isEmpty);
      expect(repositorio.buscasDeFotos, 0);
    });
  });
}
