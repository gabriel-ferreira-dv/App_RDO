import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/dados_remotos.dart';
import '../core/supabase_config.dart';
import '../core/theme/modo_do_tema.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/models/usuario.dart';
import '../features/mapa/data/datasources/permissao_mapas_service.dart';
import '../features/relatorio/turno_noturno.dart';
import '../features/sincronizacao/envio_em_segundo_plano.dart';
import 'dependencias.dart';

// Camera
typedef InicioDoApp = ({List<CameraDescription> cameras, Usuario? usuario});

Future<InicioDoApp> inicializarApp() async {
  // Sem Supabase o app segue offline só a sincronização para.
  try {
    await Supabase.initialize(
        url: supabaseUrl, publishableKey: supabasePublishableKey);
  } catch (e) {
    debugPrint('Supabase indisponível: $e');
  }

  // Pasta dos dados baixados; se falhar, vale o que vem no APK.
  try {
    await inicializarDadosRemotos();
  } catch (e) {
    debugPrint('Dados remotos indisponíveis: $e');
  }

  // Config da obra e grupos de mapa guardados no aparelho, o servidor é lido depois.
  await Dependencias.configDaObra.carregarDoAparelho();
  await PermissaoMapasService.instancia.carregarDoAparelho();
  await TurnoNoturnoService.instancia.carregarDoAparelho();
  // Claro ou escuro, se o usuário já escolheu.
  await ModoDoTema.instancia.carregar();

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Erro ao obter câmeras: $e');
  }

  // Sessão salva abre direto na Home.
  Usuario? usuario;
  try {
    usuario = await AuthService.instancia.restaurarSessao();
  } catch (e) {
    debugPrint('Erro ao restaurar sessão: $e');
  }
  // Cópias antigas da senha (sem sal) viram o formato novo, sem atrasar a abertura.
  unawaited(AuthService.instancia.protegerCopiasAntigas());

  // Envio quando a rede voltar, mesmo com o app fechado.
  await EnvioEmSegundoPlano.iniciarNoApp();

  return (cameras: cameras, usuario: usuario);
}
