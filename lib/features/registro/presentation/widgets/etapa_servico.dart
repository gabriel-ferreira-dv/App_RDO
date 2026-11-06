import 'package:flutter/material.dart';

import '../../../../core/widgets/botao_destaque.dart';
import '../viewmodels/formulario_de_registro.dart';
import '../../domain/regras/correcao_de_registro.dart' show unidadesDeMedicao;
import 'campo_pesquisa_unico.dart';
import 'escolha_de_atividade.dart';
import 'resumo_do_local.dart';

// Etapa 2 do registro: o que foi feito (atividade, serviço, passo, medição e
// descrição). Termina no botão que abre a câmera.
class EtapaServico extends StatelessWidget {
  final FormularioDeRegistro formulario;
  final VoidCallback aoAbrirGuia;
  final VoidCallback aoDitar;
  final VoidCallback aoTirarFotos;

  const EtapaServico({
    super.key,
    required this.formulario,
    required this.aoAbrirGuia,
    required this.aoDitar,
    required this.aoTirarFotos,
  });

  @override
  Widget build(BuildContext context) {
    final f = formulario;
    final theme = Theme.of(context);
    final descricaoDaAtividade = f.descricaoDaAtividadeEscolhida;

    return SingleChildScrollView(
      // Embaixo, folga para o botão do meio da barra.
      padding: const EdgeInsets.only(top: 16, bottom: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ResumoDoLocal(
              local: f.resumoDoLocal,
              via: f.pedeVia ? f.via : null,
              emNomeDe: f.registrandoPara?.nome,
              onAlterar: f.voltar,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                Text('Atividade', style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: aoAbrirGuia,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('O que é cada uma?'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EscolhaDeAtividade(
              atividades: f.atividades,
              escolhida: f.atividade,
              aoEscolher: f.escolherAtividade,
            ),
          ),
          if (descricaoDaAtividade != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                descricaoDaAtividade,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          CampoPesquisaUnico(
            key: const ValueKey('campo_servico'),
            textoPesquisa: 'Serviço',
            initialValue: f.servico,
            items: f.servicos,
            enabled: f.atividade != null,
            onSelected: f.escolherServico,
          ),
          CampoPesquisaUnico(
            key: const ValueKey('campo_servico_detalhe'),
            textoPesquisa: 'Passo do serviço',
            initialValue: f.passo,
            items: f.passos,
            enabled: f.servico != null,
            onSelected: f.escolherPasso,
          ),
          // Medição (opcional): quantidade + unidade.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: f.quantidade,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantidade (opcional)',
                      hintText: 'ex.: 120,5',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: f.unidade,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                    items: [
                      for (final u in unidadesDeMedicao)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: f.escolherUnidade,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: f.descricao,
              maxLength: 1000,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'Descrição (opcional)',
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  tooltip: f.ditando ? 'Parar o ditado' : 'Ditar a descrição',
                  icon: Icon(
                    f.ditando ? Icons.mic : Icons.mic_none,
                    color: f.ditando ? theme.colorScheme.error : null,
                  ),
                  onPressed: aoDitar,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: f.voltar,
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
                  child: const Text('Voltar'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotaoDestaque(
                    icone: Icons.photo_camera_outlined,
                    rotulo: 'Tirar fotos',
                    onPressed: aoTirarFotos,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
