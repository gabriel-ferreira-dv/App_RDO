import 'package:flutter/material.dart';

// Sem internet e sem cópia no celular (ou filial sem aviso).
class AvisoIndisponivel extends StatelessWidget {
  final VoidCallback aoTentarDeNovo;

  const AvisoIndisponivel({super.key, required this.aoTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Não foi possível carregar o aviso de privacidade. '
              'Conecte-se à internet e tente de novo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: aoTentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
