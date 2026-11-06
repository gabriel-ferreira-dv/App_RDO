import 'package:flutter/material.dart';

// Botão "Li e entendi" no pé da tela; null em [aoConfirmar] o desliga.
class BarraDeCiencia extends StatelessWidget {
  final VoidCallback? aoConfirmar;

  const BarraDeCiencia({super.key, required this.aoConfirmar});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: aoConfirmar,
          child: const Text('Li e entendi'),
        ),
      ),
    );
  }
}
