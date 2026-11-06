import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant, IsolateNameServer;

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/supabase_config.dart';
import '../auth/auth_service.dart';
import 'sincronizacao_service.dart';
import 'trava_do_envio.dart';
import '../../app/dependencias.dart';

// Envio em segundo plano: o WorkManager do Android acorda o app quando há
// internet, mesmo com ele fechado, e sobe o que ficou no aparelho (registros,
// fotos, paralisações e correções). São duas tarefas:
//   · a avulsa, agendada quando uma rodada termina com pendência (sem sinal
//     na frente de obra): roda assim que a rede voltar e, se a internet cair
//     no meio, o Android tenta de novo, esperando cada vez mais;
//   · a periódica, a cada 15 min (o mínimo do Android), de reserva.
//
// Com o app aberto, quem envia é ele: a tarefa só pede e espera. Dois
// clientes do Supabase no mesmo aparelho renovariam o mesmo token, e o
// servidor derruba a sessão quando vê um token renovado duas vezes.

const String _tarefaAvulsa = 'rdo_envio_pendente';
const String _tarefaPeriodica = 'rdo_envio_periodico';

// Nome da porta pela qual a tarefa encontra o app aberto.
const String _portaDoApp = 'rdo_envio_app_aberto';

// Mensagens do app para a tarefa.
const String _recebido = 'recebido';
const String _semRede = 'sem_rede';
const String _feito = 'feito';

// Entrada da tarefa: roda num isolate novo, sem tela.
@pragma('vm:entry-point')
void despacharTarefaDeEnvio() {
  Workmanager().executeTask((tarefa, dados) => enviarEmSegundoPlano());
}

// Lado do app aberto: liga as tarefas e atende os pedidos delas.
class EnvioEmSegundoPlano {
  EnvioEmSegundoPlano._();

  static ReceivePort? _porta;
  static AppLifecycleListener? _ciclo;

  // No main, depois do Supabase.
  static Future<void> iniciarNoApp() async {
    if (!Platform.isAndroid) return;
    _abrirPortaDoApp();
    try {
      await Workmanager().initialize(despacharTarefaDeEnvio);
      await Workmanager().registerPeriodicTask(
        _tarefaPeriodica,
        _tarefaPeriodica,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('Envio em segundo plano indisponível: $e');
      return;
    }
    // Rodada que termina com pendência deixa a tarefa avulsa esperando a rede.
    Dependencias.sincronizacao.estado.addListener(_aoTerminarRodada);
    // E ao sair do app, caso algo tenha entrado depois da última rodada.
    _ciclo ??= AppLifecycleListener(onHide: agendarSeHouverPendencia);
  }

  static void _aoTerminarRodada() {
    final estado = Dependencias.sincronizacao.estado.value;
    final pendentes = estado.pendentes;
    if (estado.enviando || pendentes == null) return;
    if (_total(pendentes) > 0) agendar();
  }

  static Future<void> agendarSeHouverPendencia() async {
    try {
      if (_total(await Dependencias.sincronizacao.contarPendentes()) > 0) {
        await agendar();
      }
    } catch (e) {
      debugPrint('Envio em segundo plano: falha ao contar pendências: $e');
    }
  }

  // Sobe o pendente assim que houver internet, mesmo com o app fechado. Se
  // já houver uma esperando (ou rodando), fica ela.
  static Future<void> agendar() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().registerOneOffTask(
        _tarefaAvulsa,
        _tarefaAvulsa,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );
    } catch (e) {
      debugPrint('Envio em segundo plano: falha ao agendar: $e');
    }
  }

  // A tarefa manda uma porta de resposta: o app avisa que recebeu, roda a
  // sincronização e avisa como terminou.
  static void _abrirPortaDoApp() {
    _porta?.close();
    final porta = _porta = ReceivePort();
    IsolateNameServer.removePortNameMapping(_portaDoApp);
    IsolateNameServer.registerPortWithName(porta.sendPort, _portaDoApp);
    porta.listen((mensagem) async {
      if (mensagem is! SendPort) return;
      mensagem.send(_recebido);
      final servico = Dependencias.sincronizacao;
      var resultado = await servico.sincronizar();
      if (resultado.erro == SincronizacaoService.erroEmAndamento) {
        await _esperarFimDaRodada(servico);
        resultado = const ResultadoSincronizacao(
            registrosEnviados: 0, fotosEnviadas: 0);
      }
      mensagem.send(resultado.semRede ? _semRede : _feito);
    });
  }

  // Uma rodada deste isolate já estava em andamento: a tarefa espera ela
  // acabar, senão o Android congela o app no meio do envio.
  static Future<void> _esperarFimDaRodada(SincronizacaoService servico) async {
    if (!servico.estado.value.enviando) return;
    final fim = Completer<void>();
    void ouvir() {
      if (!servico.estado.value.enviando && !fim.isCompleted) fim.complete();
    }

    servico.estado.addListener(ouvir);
    await fim.future;
    servico.estado.removeListener(ouvir);
  }
}

int _total(({int registros, int fotos, int paralisacoes}) p) =>
    p.registros + p.fotos + p.paralisacoes;

// Corpo da tarefa. true = feito (ou nada a fazer); false = o Android tenta
// de novo mais tarde.
Future<bool> enviarEmSegundoPlano() async {
  try {
    DartPluginRegistrant.ensureInitialized();
    // Só a fila de envio: o que vem do servidor espera o app abrir (a tarefa
    // roda a cada 15 min e não precisa gastar o plano de dados à toa).
    if (_total(await Dependencias.sincronizacao.contarPendentes()) == 0) {
      return true;
    }

    final app = IsolateNameServer.lookupPortByName(_portaDoApp);
    if (app != null) {
      final resposta = await _pedirAoApp(app);
      if (resposta != null) return resposta;
      // Ninguém respondeu: a porta ficou de uma tela que já fechou.
      if (IsolateNameServer.lookupPortByName(_portaDoApp) == app) {
        IsolateNameServer.removePortNameMapping(_portaDoApp);
      }
    }
    return await _enviarSozinho();
  } catch (e) {
    debugPrint('Envio em segundo plano falhou: $e');
    return false;
  }
}

// Pede o envio ao app aberto. null = o app não respondeu.
Future<bool?> _pedirAoApp(SendPort app) async {
  final resposta = ReceivePort();
  final mensagens = StreamIterator<dynamic>(resposta);
  try {
    app.send(resposta.sendPort);
    final recebeu = await mensagens
        .moveNext()
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
    if (!recebeu) return null;
    // O Android encerra a tarefa com 10 min; um pouco antes, desiste.
    final terminou = await mensagens
        .moveNext()
        .timeout(const Duration(minutes: 9), onTimeout: () => false);
    return terminou && mensagens.current != _semRede;
  } finally {
    resposta.close();
  }
}

// App fechado: a tarefa sobe o Supabase e a sessão guardada e envia.
Future<bool> _enviarSozinho() async {
  final trava = await TravaDoEnvio.doAparelho();
  // O app (aberto agora) ou a outra tarefa já está enviando.
  if (!await trava.pegar()) return true;
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    // Sem login online não há como enviar; fica para quando abrir o app.
    if (Supabase.instance.client.auth.currentSession == null) return true;
    if (await AuthService.instancia.restaurarSessao() == null) return true;
    // A filial decide a pasta das fotos no bucket.
    await Dependencias.configDaObra.carregarDoAparelho();

    final resultado = await Dependencias.sincronizacao.sincronizar();
    debugPrint('Envio em segundo plano: ${resultado.registrosEnviados} '
        'registro(s), ${resultado.fotosEnviadas} foto(s)'
        '${resultado.erro == null ? '' : ' — ${resultado.erro}'}');
    return !resultado.semRede;
  } finally {
    await trava.soltar();
  }
}
