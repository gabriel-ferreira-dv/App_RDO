import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/privacidade/domain/entities/ciencia_do_aviso.dart';
import 'package:namer_app/features/privacidade/domain/entities/linha_do_aviso.dart';
import 'package:namer_app/features/privacidade/domain/usecases/buscar_aviso_pendente.dart';
import 'package:namer_app/features/privacidade/domain/usecases/confirmar_leitura_do_aviso.dart';

import 'fakes.dart';

void main() {
  group('Linhas do aviso', () {
    test('"# " vira título e as linhas em branco se juntam', () {
      final linhas = linhasDoAviso('\r\n\n$textoDeExemplo\n\n');
      expect(linhas.map((l) => l.ehTitulo ? '#${l.texto}' : l.texto), [
        'Como o RDO cbm usa os seus dados.',
        '',
        '#Em resumo',
        '- Usa só o necessário.',
        '',
        '#Seus direitos',
        'Você pode pedir acesso e correção.',
      ]);
    });

    test('"#" sozinho não vira título vazio', () {
      expect(linhasDoAviso('#\n##  \ntexto').map((l) => l.texto), ['texto']);
    });
  });

  test('a ciência cobre a versão lida e as anteriores', () {
    final ciencia = CienciaDoAviso(2, DateTime(2026, 10, 22));
    expect(ciencia.cobre(1), isTrue);
    expect(ciencia.cobre(2), isTrue);
    expect(ciencia.cobre(3), isFalse);
  });

  group('Buscar aviso pendente', () {
    late RepositorioFalso repositorio;
    late BuscarAvisoPendente buscar;

    setUp(() {
      repositorio = RepositorioFalso();
      buscar = BuscarAvisoPendente(repositorio);
    });

    test('sem aviso na filial, nada pendente', () async {
      expect(await buscar(email: 'ana@cbm.com', filial: '010152'), isNull);
    });

    test('nunca leu: o aviso fica pendente', () async {
      repositorio.avisos['010152'] = avisoDe('010152', 1);
      final pendente = await buscar(email: 'ana@cbm.com', filial: '010152');
      expect(pendente?.versao, 1);
    });

    test('leu esta versão: nada pendente; versão nova: pendente', () async {
      repositorio.avisos['010152'] = avisoDe('010152', 2);
      repositorio.ciencias['010152|ana@cbm.com'] =
          CienciaDoAviso(2, DateTime(2026, 10, 22));
      expect(await buscar(email: 'ana@cbm.com', filial: '010152'), isNull);

      repositorio.avisos['010152'] = avisoDe('010152', 3);
      expect((await buscar(email: 'ana@cbm.com', filial: '010152'))?.versao, 3);
    });

    test('ciência de outra filial não vale', () async {
      repositorio.avisos['020300'] = avisoDe('020300', 1);
      repositorio.ciencias['010152|ana@cbm.com'] =
          CienciaDoAviso(9, DateTime(2026, 10, 22));
      expect(await buscar(email: 'ana@cbm.com', filial: '020300'), isNotNull);
    });

    // A filial do perfil pode vir com espaço no fim; o aviso vem sem. A
    // ciência é guardada e procurada com a filial do aviso.
    test('filial do perfil com espaço: depois de ler, nada pendente',
        () async {
      repositorio.avisos['010152 '] = avisoDe('010152', 1);
      final pendente = await buscar(email: 'ana@cbm.com', filial: '010152 ');
      await ConfirmarLeituraDoAviso(repositorio)('ana@cbm.com', pendente!);
      expect(await buscar(email: 'ana@cbm.com', filial: '010152 '), isNull);
    });
  });

  test('confirmar a leitura guarda a versão e a hora', () async {
    final repositorio = RepositorioFalso();
    final agora = DateTime(2026, 10, 23, 7, 30);
    await ConfirmarLeituraDoAviso(repositorio, agora: () => agora)(
        'ana@cbm.com', avisoDe('010152', 4));

    final ciencia = repositorio.ciencias['010152|ana@cbm.com']!;
    expect(ciencia.versao, 4);
    expect(ciencia.quando, agora);
  });
}
