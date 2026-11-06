import 'package:flutter/foundation.dart';

import '../core/localizacao_service.dart';
import '../core/obra/config_da_obra.dart' show obraAtualNotifier;
import '../core/obra/dia_de_trabalho.dart';
import '../core/obra/filial_do_usuario.dart';
import '../features/admin/data/datasources/admin_local_datasource.dart';
import '../features/admin/data/datasources/admin_remoto_datasource.dart';
import '../features/admin/data/repositories/admin_repository_impl.dart';
import '../features/admin/domain/repositories/admin_repository.dart';
import '../features/admin/domain/usecases/carregar_registros_dos_usuarios.dart';
import '../features/admin/presentation/viewmodels/registros_dos_usuarios_view_model.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/models/usuario.dart';
import '../features/historico/data/repositories/historico_repository_impl.dart';
import '../features/historico/domain/repositories/historico_repository.dart';
import '../features/historico/presentation/viewmodels/historico_view_model.dart';
import '../features/mapa/data/datasources/navegacao_estacas_service.dart';
import '../features/mapa/data/datasources/permissao_mapas_service.dart';
import '../features/mapa/domain/entities/estaca_navegavel.dart';
import '../features/mapa/presentation/viewmodels/escolha_de_estaca_view_model.dart';
import '../features/mapa/presentation/viewmodels/mapa_view_model.dart';
import '../features/obra/config_da_obra_service.dart';
import '../features/paralisacao/data/datasources/paralisacao_local_datasource.dart';
import '../features/paralisacao/data/repositories/paralisacao_repository_impl.dart';
import '../features/paralisacao/domain/entities/paralisacao.dart';
import '../features/paralisacao/domain/repositories/paralisacao_repository.dart';
import '../features/paralisacao/domain/usecases/carregar_paralisacoes_do_dia.dart';
import '../features/paralisacao/domain/usecases/esta_parado_agora.dart';
import '../features/paralisacao/domain/usecases/retomar_servico.dart';
import '../features/paralisacao/domain/usecases/salvar_paralisacao.dart';
import '../features/paralisacao/presentation/viewmodels/paralisacao_form_view_model.dart';
import '../features/paralisacao/presentation/viewmodels/paralisacoes_do_dia_view_model.dart';
import '../features/paralisacao/presentation/viewmodels/paralisacoes_view_model.dart';
import '../features/privacidade/data/datasources/aviso_local_datasource.dart';
import '../features/privacidade/data/datasources/aviso_remoto_datasource.dart';
import '../features/privacidade/data/repositories/aviso_de_privacidade_repository_impl.dart';
import '../features/privacidade/domain/entities/aviso_de_privacidade.dart';
import '../features/privacidade/domain/repositories/aviso_de_privacidade_repository.dart';
import '../features/privacidade/domain/usecases/buscar_aviso_pendente.dart';
import '../features/privacidade/domain/usecases/carregar_aviso_de_privacidade.dart';
import '../features/privacidade/domain/usecases/confirmar_leitura_do_aviso.dart';
import '../features/privacidade/presentation/viewmodels/privacidade_view_model.dart';
import '../features/registro/data/datasources/ditado_por_voz.dart';
import '../features/registro/data/datasources/edicao_registro_service.dart'
    show EdicaoRegistroService;
import '../features/registro/data/datasources/estaqueamento_service.dart';
import '../features/registro/data/datasources/sugestao_gps_service.dart';
import '../features/registro/data/repositories/catalogo_da_obra_csv.dart';
import '../features/registro/data/repositories/registro_repository_impl.dart';
import '../features/registro/domain/entities/campos_do_registro.dart';
import '../features/registro/domain/repositories/catalogo_da_obra.dart';
import '../features/registro/domain/repositories/registro_repository.dart';
import '../features/registro/presentation/viewmodels/editar_registro_view_model.dart';
import '../features/registro/presentation/viewmodels/formulario_de_registro.dart';
import '../features/registro/presentation/viewmodels/importar_atividade_view_model.dart';
import '../features/relatorio/equipe_simova_service.dart';
import '../features/relatorio/turno_noturno.dart' show TurnoNoturnoService;
import '../features/sincronizacao/atualizacao_app_service.dart';
import '../features/sincronizacao/atualizacao_dados_service.dart';
import '../features/sincronizacao/sincronizacao_service.dart';
import '../features/supervisor/data/datasources/equipe_supabase.dart';
import '../features/supervisor/data/datasources/registros_equipe_supabase.dart';
import '../features/supervisor/data/datasources/relatorio_consolidado_pdf.dart';
import '../features/supervisor/data/repositories/equipe_repository_impl.dart';
import '../features/supervisor/data/repositories/registros_da_equipe_repository_impl.dart';
import '../features/supervisor/domain/entities/encarregado_da_equipe.dart';
import '../features/supervisor/domain/repositories/equipe_repository.dart';
import '../features/supervisor/domain/repositories/registros_da_equipe_repository.dart';
import '../features/supervisor/domain/usecases/baixar_fotos_do_consolidado.dart';
import '../features/supervisor/domain/usecases/carregar_dia_da_equipe.dart';
import '../features/supervisor/domain/usecases/registros_do_aparelho_no_dia.dart';
import '../features/supervisor/presentation/viewmodels/mapa_avanco_view_model.dart';
import '../features/supervisor/presentation/viewmodels/montar_equipe_view_model.dart';
import '../features/supervisor/presentation/viewmodels/supervisor_view_model.dart';


abstract final class Dependencias {
  // Sessão


  static final filial = FilialDoUsuario();

  // A matrícula que vale: a do perfil renovado no servidor, ou a guardada.
  static String matriculaDe(Usuario usuario) =>
      AuthService.instancia.usuarioLogado?.matricula ?? usuario.matricula;

  // Turno da noite
  static bool ehNoturno(Usuario usuario) =>
      TurnoNoturnoService.instancia.ehNoturno(matriculaDe(usuario));

  // O "hoje" de trabalho do usuário (o turno é lido a cada uso).
  static RelogioDoTurno relogioDe(Usuario usuario) =>
      RelogioDoTurno(noturno: () => ehNoturno(usuario));

  // Obra, dados do projeto e envio

  static final configDaObra = ConfigDaObraService(filial);

  static final atualizacaoDados = AtualizacaoDadosService(filial);

  static final atualizacaoApp = AtualizacaoAppService(atualizacaoDados);

  static final sincronizacao =
      SincronizacaoService(configDaObra: configDaObra, filial: filial);

  // Manda ao servidor o que está pendente quando houver rede.
  static void enviarPendentes() => sincronizacao.sincronizar();

  // Liga o GPS e pede a permissão na primeira vez.
  static void iniciarGps() => LocalizacaoService.instancia.iniciar();

  static MapaViewModel mapa() => MapaViewModel(
        posicao: LocalizacaoService.instancia.posicao,
        mudancasNosMapas: Listenable.merge([
          PermissaoMapasService.instancia.grupos,
          obraAtualNotifier,
        ]),
      );

  static EscolhaDeEstacaViewModel escolhaDeEstaca(
          EstacaNavegavel? destinoAtual) =>
      EscolhaDeEstacaViewModel(
        repositorio: NavegacaoEstacasService.instancia,
        destinoAtual: destinoAtual,
      );

  // Autorzação de privacidade

  static const AvisoDePrivacidadeRepository avisoDePrivacidade =
      AvisoDePrivacidadeRepositoryImpl(
    remoto: AvisoRemotoSupabase(),
    local: AvisoLocalPrefs(),
  );

  static BuscarAvisoPendente get buscarAvisoPendente =>
      const BuscarAvisoPendente(avisoDePrivacidade);

  static PrivacidadeViewModel privacidade({
    String email = '',
    AvisoDePrivacidade? avisoPendente,
  }) =>
      PrivacidadeViewModel(
        carregarAviso: const CarregarAvisoDePrivacidade(avisoDePrivacidade),
        confirmarLeitura: const ConfirmarLeituraDoAviso(avisoDePrivacidade),
        filial: filial.codigo,
        email: email,
        avisoPendente: avisoPendente,
      );

  // Registro
  static const RegistroRepository registros = RegistroRepositoryImpl();
  static const CatalogoDaObra catalogo = CatalogoDaObraCsv();

  static FormularioDeRegistro formularioDeRegistro() => FormularioDeRegistro(
        catalogo: catalogo,
        estacas: EstaqueamentoService.instancia,
        localizacao: SugestaoGpsService.instancia,
        registros: registros,
        ditado: DitadoPorVoz(),
      );

  static EditarRegistroViewModel editarRegistro(CamposDoRegistro campos) =>
      EditarRegistroViewModel(
        catalogo: catalogo,
        estacas: EstaqueamentoService.instancia,
        original: campos,
      );

  static ImportarAtividadeViewModel importarAtividade(Usuario usuario) =>
      ImportarAtividadeViewModel(registros: registros, usuarioId: usuario.id!);

  // Paralisação

  static const ParalisacaoRepository paralisacoes =
      ParalisacaoRepositoryImpl(ParalisacaoSqflite());

  static EstaParadoAgora get estaParadoAgora =>
      const EstaParadoAgora(paralisacoes);

  static ParalisacoesViewModel abaDeParalisacoes(Usuario usuario) =>
      ParalisacoesViewModel(
        relogio: relogioDe(usuario),
        mudancasNoTurno: TurnoNoturnoService.instancia.mudancas,
      );

  static ParalisacoesDoDiaViewModel paralisacoesDoDia({
    required Usuario usuario,
    DateTime? dia,
    VoidCallback? aoMudar,
  }) =>
      ParalisacoesDoDiaViewModel(
        carregarDoDia: const CarregarParalisacoesDoDia(paralisacoes),
        retomarServico: const RetomarServico(paralisacoes),
        usuarioId: usuario.id!,
        relogio: relogioDe(usuario),
        dia: dia,
        // O supervisor vê a mudança assim que houver rede.
        aoMudarDados: () {
          enviarPendentes();
          aoMudar?.call();
        },
      );

  static ParalisacaoFormViewModel formularioDeParalisacao({
    required int usuarioId,
    required DateTime dia,
    required bool noturno,
    Paralisacao? paralisacao,
  }) =>
      ParalisacaoFormViewModel(
        salvarParalisacao: const SalvarParalisacao(paralisacoes),
        repositorio: paralisacoes,
        carregarTrechos: catalogo.trechos,
        carregarKms: catalogo.kms,
        usuarioId: usuarioId,
        dia: dia,
        noturno: noturno,
        existente: paralisacao,
      );

  // Histórico

  static final HistoricoRepository historicoRepositorio =
      HistoricoRepositoryImpl(
    fotosDoUsuario: registros.listarFotosComContexto,
    camposDe: EdicaoRegistroService.instancia.campos,
    editar: EdicaoRegistroService.instancia.editar,
  );

  static HistoricoViewModel historico(Usuario usuario) => HistoricoViewModel(
        repositorio: historicoRepositorio,
        usuarioId: usuario.id!,
        // A correção vai para o servidor assim que houver rede.
        aoCorrigir: enviarPendentes,
      );

  // Admin do painel

  static final AdminRepository admin = AdminRepositoryImpl(
    remoto: const AdminRemotoSupabase(),
    local: const AdminLocalPrefs(),
    ehNoturno: TurnoNoturnoService.instancia.ehNoturno,
    caminhosDasFotos: registrosDaEquipe.caminhosDasFotos,
    corrigirNoServidor: registrosDaEquipe.corrigir,
  );

  static RegistrosDosUsuariosViewModel registrosDosUsuarios() =>
      RegistrosDosUsuariosViewModel(
        carregarDoDia: CarregarRegistrosDosUsuarios(admin),
        repositorio: admin,
      );

  // Supervisor

  static final EquipeRepository equipe = EquipeRepositoryImpl(
    remota: const EquipeSupabase(),
    encarregadosDoApontamento: EquipeSimovaService.instancia.listarEncarregados,
  );

  static final RegistrosDaEquipeRepository registrosDaEquipe =
      RegistrosDaEquipeRepositoryImpl(
    remoto: const RegistrosEquipeSupabase(),
    efetivoDoDia: EquipeSimovaService.instancia.equipesDoDia,
  );

  static SupervisorViewModel supervisor(Usuario usuario) => SupervisorViewModel(
        equipe: equipe,
        registros: registrosDaEquipe,
        carregarDia: CarregarDiaDaEquipe(registrosDaEquipe,
            ehNoturno: TurnoNoturnoService.instancia.ehNoturno),
        baixarFotos: BaixarFotosDoConsolidado(registrosDaEquipe),
        gerarPdf: gerarPdfDaEquipe,
        matricula: () => matriculaDe(usuario),
        supervisorNome: usuario.nome,
        relogio: relogioDe(usuario),
        // O banco lê a matrícula de dentro do token, e quem é da noite muda o
        // dia de cada um.
        prepararSessao: () async {
          await AuthService.instancia.sincronizarPerfil();
          await TurnoNoturnoService.instancia.sincronizar();
        },
      );

  static MontarEquipeViewModel montarEquipe(
          String supervisorMatricula, List<EncarregadoDaEquipe> equipeAtual) =>
      MontarEquipeViewModel(
        repositorio: equipe,
        supervisorMatricula: supervisorMatricula,
        equipeAtual: equipeAtual,
      );

  static MapaAvancoViewModel mapaDaEquipe(List<String> matriculas) =>
      MapaAvancoViewModel(
        estacasDoProjeto: NavegacaoEstacasService.instancia.todas,
        registrosDaEquipe: (desde) =>
            registrosDaEquipe.registrosDoPeriodo(matriculas, desde: desde),
      );

  static MapaAvancoViewModel mapaDoEncarregado(Usuario usuario, {DateTime? dia}) =>
      MapaAvancoViewModel(
        estacasDoProjeto: NavegacaoEstacasService.instancia.todas,
        registrosDoDia: RegistrosDoAparelhoNoDia(
          registros,
          usuarioId: usuario.id!,
          nome: usuario.nome,
          matricula: matriculaDe(usuario),
          noturno: () => ehNoturno(usuario),
        ).call,
        relogio: relogioDe(usuario),
        dia: dia,
      );
}
