import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/sincronizacao/trava_do_envio.dart';

void main() {
  late Directory pasta;
  late File arquivo;

  setUp(() {
    pasta = Directory.systemTemp.createTempSync('trava_do_envio');
    arquivo = File('${pasta.path}/envio.trava');
  });
  tearDown(() => pasta.deleteSync(recursive: true));

  test('enquanto o app envia, a tarefa em segundo plano não pega a trava',
      () async {
    final app = TravaDoEnvio(arquivo);
    final tarefa = TravaDoEnvio(arquivo);

    expect(await app.pegar(), isTrue);
    expect(await tarefa.pegar(), isFalse);

    await app.soltar();
    expect(arquivo.existsSync(), isFalse);
    expect(await tarefa.pegar(), isTrue);
    await tarefa.soltar();
  });

  test('quem já segura pode pegar de novo, e só solta no último soltar',
      () async {
    final tarefa = TravaDoEnvio(arquivo);
    expect(await tarefa.pegar(), isTrue);
    expect(await tarefa.pegar(), isTrue);

    await tarefa.soltar();
    expect(arquivo.existsSync(), isTrue);
    expect(await TravaDoEnvio(arquivo).pegar(), isFalse);

    await tarefa.soltar();
    expect(arquivo.existsSync(), isFalse);
  });

  test('trava de um processo que já morreu não vale', () async {
    // App fechado no meio do envio: o arquivo ficou com o pid antigo.
    arquivo.writeAsStringSync('999999;${DateTime.now().millisecondsSinceEpoch}');
    final trava = TravaDoEnvio(arquivo, processo: 1234);
    expect(await trava.pegar(), isTrue);
    expect(arquivo.readAsStringSync(), startsWith('1234;'));
    await trava.soltar();
  });

  test('trava sem renovação há mais que a validade não vale', () async {
    final antiga = DateTime.now()
        .subtract(const Duration(minutes: 5))
        .millisecondsSinceEpoch;
    arquivo.writeAsStringSync('1234;$antiga');
    final trava = TravaDoEnvio(arquivo, processo: 1234);
    expect(await trava.pegar(), isTrue);
    await trava.soltar();
  });

  test('trava recente do mesmo processo vale, mesmo ainda sem conteúdo',
      () async {
    arquivo.writeAsStringSync('1234;${DateTime.now().millisecondsSinceEpoch}');
    expect(await TravaDoEnvio(arquivo, processo: 1234).pegar(), isFalse);

    // Outro isolate acabou de criar e ainda não escreveu.
    arquivo.writeAsStringSync('');
    expect(await TravaDoEnvio(arquivo, processo: 1234).pegar(), isFalse);
  });

  test('soltar sem ter pegado não apaga a trava dos outros', () async {
    final app = TravaDoEnvio(arquivo);
    expect(await app.pegar(), isTrue);
    await TravaDoEnvio(arquivo).soltar();
    expect(arquivo.existsSync(), isTrue);
    await app.soltar();
  });
}
