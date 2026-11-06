import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/features/privacidade/data/datasources/aviso_local_datasource.dart';
import 'package:namer_app/features/privacidade/data/models/aviso_de_privacidade_model.dart';
import 'package:namer_app/features/privacidade/data/models/ciencia_do_aviso_model.dart';
import 'package:namer_app/features/privacidade/data/repositories/aviso_de_privacidade_repository_impl.dart';
import 'package:namer_app/features/privacidade/domain/entities/ciencia_do_aviso.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  group('Modelos', () {
    test('linha da tabela vira aviso e volta igual', () {
      final aviso = avisoDoMapa({
        'filial_id': '010152',
        'versao': 2,
        'texto': ' $textoDeExemplo ',
        'atualizado_em': '2026-10-22T13:00:00.000Z',
      })!;
      expect(aviso.filial, '010152');
      expect(aviso.versao, 2);
      expect(aviso.texto, textoDeExemplo.trim());

      final deVolta = avisoDoMapa(aviso.paraMapa())!;
      expect(deVolta.texto, aviso.texto);
      expect(deVolta.atualizadoEm, aviso.atualizadoEm);
    });

    test('linha sem texto não vira aviso; sem versão vale 1', () {
      expect(avisoDoMapa({'versao': 1, 'texto': '  '}), isNull);
      expect(avisoDoMapa({'texto': 'x'})!.versao, 1);
    });

    test('ciência vira texto e volta; valor estranho é não lido', () {
      final ciencia = CienciaDoAviso(3, DateTime(2026, 10, 22, 8));
      final deVolta = cienciaDoTexto(ciencia.paraTexto())!;
      expect(deVolta.versao, 3);
      expect(deVolta.quando, ciencia.quando);

      for (final estranho in [null, '', 'x|y', '3']) {
        expect(cienciaDoTexto(estranho), isNull, reason: '$estranho');
      }
    });
  });

  group('Repositório', () {
    late RemotoFalso remoto;
    late LocalFalso local;
    late AvisoDePrivacidadeRepositoryImpl repositorio;

    setUp(() {
      remoto = RemotoFalso();
      local = LocalFalso();
      repositorio =
          AvisoDePrivacidadeRepositoryImpl(remoto: remoto, local: local);
    });

    test('com internet, devolve o do servidor e guarda a cópia', () async {
      remoto.linha = avisoDe('010152', 5).paraMapa();
      expect((await repositorio.buscar('010152'))?.versao, 5);
      expect(local.dados['copia:010152'], isNotNull);
    });

    test('sem internet, usa a cópia da filial', () async {
      local.dados['copia:010152'] = jsonEncode(avisoDe('010152', 3).paraMapa());
      remoto.erro = const SocketException('sem rede');
      expect((await repositorio.buscar('010152'))?.versao, 3);
    });

    test('servidor sem aviso para a filial: usa a cópia, se houver', () async {
      expect(await repositorio.buscar('010152'), isNull);
      local.dados['copia:010152'] = jsonEncode(avisoDe('010152', 2).paraMapa());
      expect((await repositorio.buscar('010152'))?.versao, 2);
    });

    test('cópia estragada conta como sem aviso', () async {
      remoto.erro = const SocketException('sem rede');
      local.dados['copia:010152'] = '{quebrado';
      expect(await repositorio.buscar('010152'), isNull);
    });

    test('guarda e lê a ciência', () async {
      await repositorio.guardarCiencia(
          'ana@cbm.com', '010152', CienciaDoAviso(2, DateTime(2026, 10, 22)));
      expect((await repositorio.ciencia('ana@cbm.com', '010152'))?.versao, 2);
      expect(await repositorio.ciencia('ana@cbm.com', '020300'), isNull);
    });
  });

  group('Celular (SharedPreferences)', () {
    const local = AvisoLocalPrefs();

    test('ciência por filial e por e-mail, sem diferença de maiúsculas',
        () async {
      SharedPreferences.setMockInitialValues({});
      await local.guardarCiencia(' ANA@cbm.com ', '010152', '1|x');
      expect(await local.ciencia('ana@cbm.com', '010152'), '1|x');
      expect(await local.ciencia('bia@cbm.com', '010152'), isNull);
      expect(await local.ciencia('ana@cbm.com', '020300'), isNull);
    });

    test('cópia por filial', () async {
      SharedPreferences.setMockInitialValues({});
      await local.guardarCopia('010152', '{"a":1}');
      expect(await local.copia('010152'), '{"a":1}');
      expect(await local.copia('020300'), isNull);
    });
  });
}
