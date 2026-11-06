import 'package:flutter/material.dart';

import '../../../../app/dependencias.dart';
import '../../../../core/widgets/seletor_de_dia.dart';
import '../../../auth/models/usuario.dart';
import '../viewmodels/paralisacoes_view_model.dart';
import '../widgets/paralisacoes_do_dia.dart';

// Aba "Paradas": as paralisações de um dia, com registrar e retomar.
class ParalisacoesPage extends StatefulWidget {
  final Usuario usuario;

  // Avisa a Home quando algo muda (o ponto vermelho da aba).
  final VoidCallback? aoMudar;

  // Para testes: um ViewModel já montado no lugar do padrão.
  final ParalisacoesViewModel? viewModel;

  const ParalisacoesPage({
    super.key,
    required this.usuario,
    this.aoMudar,
    this.viewModel,
  });

  @override
  State<ParalisacoesPage> createState() => _ParalisacoesPageState();
}

class _ParalisacoesPageState extends State<ParalisacoesPage> {
  late final ParalisacoesViewModel _vm =
      widget.viewModel ?? Dependencias.abaDeParalisacoes(widget.usuario);

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SeletorDeDia(dia: _vm.dia, hoje: _vm.hoje, aoMudar: _vm.mudarDia),
          const SizedBox(height: 8),
          // A chave recria o cartão (e o ViewModel dele) ao trocar de dia.
          ParalisacoesDoDia(
            key: ValueKey(_vm.dia),
            usuario: widget.usuario,
            dia: _vm.dia,
            aoMudar: widget.aoMudar,
          ),
          const SizedBox(height: 16),
          Text(
            'Registre toda vez que o serviço parar: chuva, falta de material, '
            'máquina quebrada, interferência. O horário, o motivo e as fotos '
            'vão para o RDO e para o relatório do supervisor, e provam que a '
            'parada não foi culpa da obra.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
