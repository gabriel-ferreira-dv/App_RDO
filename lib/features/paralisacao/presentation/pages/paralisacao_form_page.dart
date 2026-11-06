import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../../../core/widgets/galeria_imagens_page.dart';
import '../../../camera/presentation/pages/camera_page.dart';
import '../../domain/entities/paralisacao.dart';
import '../../domain/usecases/salvar_paralisacao.dart';
import '../viewmodels/paralisacao_form_view_model.dart';
import '../widgets/fotos_da_parada.dart';
import '../widgets/horarios_da_parada.dart';
import '../widgets/local_da_parada.dart';
import '../widgets/seletor_de_motivo.dart';

// Nova paralisação ou edição de uma existente. Só desenha o ViewModel e
// cuida do que é de tela (relógio, câmera, diálogo, avisos); abra pela rota
// em app/rotas.dart. Fecha com true quando salvou ou excluiu.
//
// A tela é dona do ViewModel e o cria uma vez só, no State: o builder da rota
// pode rodar de novo, e um ViewModel criado lá trocaria o que está em uso
// por um novo (sem o id da paralisação já salva, e ela seria gravada duas
// vezes).
class ParalisacaoFormPage extends StatefulWidget {
  final int usuarioId;

  // Dia de trabalho de uma paralisação nova.
  final DateTime dia;
  final bool noturno;

  // A paralisação a editar; null = nova.
  final Paralisacao? paralisacao;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final ParalisacaoFormViewModel? viewModel;

  const ParalisacaoFormPage({
    super.key,
    required this.usuarioId,
    required this.dia,
    required this.noturno,
    this.paralisacao,
    this.viewModel,
  });

  @override
  State<ParalisacaoFormPage> createState() => _ParalisacaoFormPageState();
}

class _ParalisacaoFormPageState extends State<ParalisacaoFormPage> {
  late final ParalisacaoFormViewModel _vm = widget.viewModel ??
      Dependencias.formularioDeParalisacao(
        usuarioId: widget.usuarioId,
        dia: widget.dia,
        noturno: widget.noturno,
        paralisacao: widget.paralisacao,
      );
  late final _observacao = TextEditingController(text: _vm.observacao);

  @override
  void initState() {
    super.initState();
    _vm.iniciar();
  }

  @override
  void dispose() {
    _observacao.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _escolherInicio() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_vm.inicio),
      helpText: 'Parou às',
    );
    if (hora != null) _vm.definirInicio(hora.hour, hora.minute);
  }

  Future<void> _escolherFim() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_vm.fim ?? DateTime.now()),
      helpText: 'Voltou às',
    );
    if (hora != null) _vm.definirFim(hora.hour, hora.minute);
  }

  // true quando gravou; senão avisa o que falta.
  Future<bool> _salvar() async {
    final resultado = await _vm.salvar();
    if (resultado case NaoSalvou(:final problema)) {
      _avisar(problema);
      return false;
    }
    return true;
  }

  Future<void> _salvarEFechar() async {
    if (await _salvar() && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _salvarEFotografar() async {
    if (!await _salvar() || !mounted) return;
    List<CameraDescription> cameras = [];
    try {
      cameras = await availableCameras();
    } catch (e) {
      debugPrint('Paralisação: câmera indisponível: $e');
    }
    if (!mounted) return;
    if (cameras.isEmpty) {
      _avisar('Câmera indisponível neste aparelho');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CameraPage(
        cameras: cameras,
        aoSalvarFoto: (caminho, posicao) => _vm.registrarFoto(caminho,
            latitude: posicao.latitude, longitude: posicao.longitude),
        trecho: _vm.trecho ?? '',
        kmtrecho: _vm.km ?? '',
        estacaInicial: '',
        estacaFinal: '',
        via: '',
        descricao: _vm.observacao.trim(),
        servNotavel: _vm.servicoNoCarimbo,
        servNotavelDetalhes: _vm.detalheNoCarimbo,
      ),
    ));
    await _vm.recarregarFotos();
  }

  Future<void> _excluir() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir paralisação?'),
        content:
            const Text('Ela sai do relatório. As fotos ficam no aparelho.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmado != true || !_vm.jaGravada) return;
    await _vm.excluir();
    if (mounted) Navigator.of(context).pop(true);
  }

  void _abrirGaleria() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GaleriaImagensPage(
          fotos: _vm.caminhosDasFotos,
          descricao: _vm.observacao.trim(),
        ),
      ));

  void _avisar(String texto) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_vm.titulo),
          actions: [
            if (_vm.jaGravada)
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline),
                onPressed: _vm.salvando ? null : _excluir,
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SeletorDeMotivo(
              motivos: motivosParalisacao,
              escolhido: _vm.motivo,
              aoEscolher: _vm.escolherMotivo,
            ),
            const SizedBox(height: 20),
            HorariosDaParada(
              rotuloInicio: _vm.rotuloInicio,
              rotuloFim: _vm.rotuloFim,
              avisoDeOutroDia: _vm.avisoDeOutroDia,
              aindaParado: _vm.aindaParado,
              aoEscolherInicio: _escolherInicio,
              aoEscolherFim: _escolherFim,
              aoMudarAindaParado: _vm.definirAindaParado,
            ),
            const SizedBox(height: 8),
            LocalDaParada(
              trechos: _vm.trechos,
              trecho: _vm.trecho,
              kms: _vm.kms,
              km: _vm.km,
              aoEscolherTrecho: _vm.escolherTrecho,
              aoEscolherKm: _vm.escolherKm,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _observacao,
              onChanged: _vm.definirObservacao,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                hintText: 'Ex.: chuva forte, pista alagada no KM 225',
                border: OutlineInputBorder(),
              ),
            ),
            if (_vm.caminhosDasFotos.isNotEmpty) ...[
              const SizedBox(height: 16),
              FotosDaParada(
                  caminhos: _vm.caminhosDasFotos, aoAbrir: _abrirGaleria),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _vm.salvando ? null : _salvarEFotografar,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_vm.rotuloDaFoto),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _vm.salvando ? null : _salvarEFechar,
              icon: const Icon(Icons.check),
              label: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
