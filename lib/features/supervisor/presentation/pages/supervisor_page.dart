import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../app/dependencias.dart';
import '../../../../core/widgets/seletor_de_dia.dart';
import '../../../auth/models/usuario.dart';
import '../../../registro/domain/entities/campos_do_registro.dart';
import '../../../registro/presentation/pages/editar_registro_page.dart';
import '../../domain/entities/encarregado_da_equipe.dart';
import '../../domain/entities/registro_da_equipe.dart';
import '../viewmodels/supervisor_view_model.dart';
import '../widgets/cartao_do_encarregado.dart';
import '../widgets/equipe_vazia.dart';
import 'mapa_avanco_page.dart';
import 'montar_equipe_page.dart';

// Aba Equipe do supervisor: o dia de cada encarregado e o relatório
// consolidado. Só desenha o ViewModel e cuida da navegação.
class SupervisorPage extends StatefulWidget {
  final Usuario usuario;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final SupervisorViewModel? viewModel;

  const SupervisorPage({super.key, required this.usuario, this.viewModel});

  @override
  State<SupervisorPage> createState() => _SupervisorPageState();
}

class _SupervisorPageState extends State<SupervisorPage> {
  late final SupervisorViewModel _vm =
      widget.viewModel ?? Dependencias.supervisor(widget.usuario);

  @override
  void initState() {
    super.initState();
    _vm.carregar();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _avisar(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _montarEquipe() async {
    if (_vm.matricula.isEmpty) {
      _avisar('Seu usuário está sem matrícula. Cadastre no Supabase e entre no '
          'app novamente');
      return;
    }
    final nova = await Navigator.of(context).push<List<EncarregadoDaEquipe>>(
      MaterialPageRoute(
        builder: (_) => MontarEquipePage(
          supervisorMatricula: _vm.matricula,
          equipeAtual: _vm.equipe,
        ),
      ),
    );
    if (nova != null) _vm.carregar();
  }

  void _abrirMapaDeAvanco() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MapaAvancoPage.daEquipe(matriculas: _vm.matriculasDoMapa),
    ));
  }

  Future<void> _gerarRelatorio() async {
    final relatorio = await _vm.gerarRelatorio();
    if (!mounted) return;
    if (relatorio == null) {
      _avisar('Não foi possível gerar o relatório. Tente de novo; se '
          'continuar, gere sem as fotos e me avise.');
      return;
    }
    _abrirPdf(relatorio);
  }

  void _abrirPdf(RelatorioDaEquipe relatorio) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(relatorio.titulo)),
        body: PdfPreview(
          build: (_) async => relatorio.bytes,
          allowSharing: true,
          allowPrinting: true,
          canChangePageFormat: false,
          pdfFileName: relatorio.arquivo,
        ),
      ),
    ));
  }

  Future<void> _corrigir(RegistroDaEquipe registro) async {
    final corrigidos = await Navigator.of(context).push<CamposDoRegistro>(
      MaterialPageRoute(
        builder: (_) => EditarRegistroPage(
          campos: registro.campos,
          subtitulo: _vm.subtituloDaCorrecao(registro),
        ),
      ),
    );
    if (corrigidos == null || !mounted) return;
    final mensagem = await _vm.corrigir(registro, corrigidos);
    if (mounted) _avisar(mensagem);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _vm.carregar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: SeletorDeDia(
                    dia: _vm.dia,
                    hoje: _vm.hoje,
                    habilitado: !_vm.carregando,
                    aoMudar: _vm.mudarDia,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _montarEquipe,
                  icon: const Icon(Icons.group_add, size: 18),
                  label: const Text('Equipe'),
                ),
              ],
            ),
            if (_vm.temEquipe) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _abrirMapaDeAvanco,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Mapa de avanço da equipe'),
              ),
            ],
            const SizedBox(height: 12),
            if (_vm.carregando)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_vm.temEquipe)
              const EquipeVazia()
            else ...[
              for (final cartao in _vm.cartoes)
                CartaoDoEncarregado(cartao: cartao, aoCorrigir: _corrigir),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _vm.incluirFotos,
                onChanged: _vm.definirIncluirFotos,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Incluir fotos no relatório',
                    style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  'Deixa o PDF bem maior e mais lento de gerar — precisa baixar '
                  'todas as fotos do dia.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _vm.gerando ? null : _gerarRelatorio,
                icon: _vm.gerando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_vm.rotuloDoRelatorio),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
