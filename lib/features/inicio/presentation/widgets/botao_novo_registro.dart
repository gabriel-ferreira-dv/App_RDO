import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';

// O botão grande e amarelo do Início: começa um registro.
class BotaoNovoRegistro extends StatelessWidget {
  final VoidCallback onTap;

  const BotaoNovoRegistro({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    return Material(
      color: cores.destaque,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: grafite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.add_a_photo_outlined, color: cores.noCabecalho),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Novo registro',
                      style: TextStyle(
                        color: cores.naDestaque,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Local, serviço e fotos',
                      style: TextStyle(color: cores.naDestaque, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: cores.naDestaque),
            ],
          ),
        ),
      ),
    );
  }
}
