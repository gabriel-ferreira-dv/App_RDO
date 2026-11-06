import 'package:flutter/material.dart';

// Os quatro itens da barra de baixo; o Registrar é o botão redondo do meio
// (FloatingActionButton encaixado na barra).
enum ItemDaBarra { inicio, historico, mapa, mais }

class BarraDeNavegacao extends StatelessWidget {
  // null quando o selecionado é o Registrar.
  final ItemDaBarra? selecionado;
  final ValueChanged<ItemDaBarra> aoEscolher;

  // Ponto vermelho no "Mais" (serviço parado agora).
  final bool alertaNoMais;

  const BarraDeNavegacao({
    super.key,
    required this.selecionado,
    required this.aoEscolher,
    this.alertaNoMais = false,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        children: [
          _item(context, ItemDaBarra.inicio, Icons.home_outlined, Icons.home,
              'Início'),
          _item(context, ItemDaBarra.historico, Icons.history, Icons.history,
              'Histórico'),
          // Espaço do botão do meio, com o nome embaixo dele.
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Registrar',
                  style: _estiloDoRotulo(context, selecionado == null),
                ),
              ),
            ),
          ),
          _item(
              context, ItemDaBarra.mapa, Icons.map_outlined, Icons.map, 'Mapa'),
          _item(context, ItemDaBarra.mais, Icons.menu, Icons.menu, 'Mais',
              alerta: alertaNoMais),
        ],
      ),
    );
  }

  TextStyle _estiloDoRotulo(BuildContext context, bool ativo) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 11.5,
      fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
      color: ativo ? cs.onSurface : cs.onSurfaceVariant,
    );
  }

  Widget _item(
    BuildContext context,
    ItemDaBarra item,
    IconData icone,
    IconData iconeAtivo,
    String rotulo, {
    bool alerta = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ativo = item == selecionado;
    return Expanded(
      child: InkResponse(
        onTap: () => aoEscolher(item),
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: ativo ? cs.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Badge(
                isLabelVisible: alerta,
                child: Icon(
                  ativo ? iconeAtivo : icone,
                  color: ativo ? cs.onSecondaryContainer : cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(rotulo, style: _estiloDoRotulo(context, ativo)),
          ],
        ),
      ),
    );
  }
}
