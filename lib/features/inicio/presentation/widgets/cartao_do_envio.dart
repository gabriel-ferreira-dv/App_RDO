import 'package:flutter/material.dart';

import '../../../../core/theme/cores_app.dart';
import '../../../sincronizacao/sincronizacao_service.dart';
import '../../../sincronizacao/situacao_do_envio.dart';

// Cartão do Início com o estado do envio ("3 fotos aguardando sinal", "Tudo
// enviado"). Toca para abrir a tela de Atualizações, que tem os detalhes.
class CartaoDoEnvio extends StatelessWidget {
  final EstadoDoEnvio estado;
  final VoidCallback? onTap;

  const CartaoDoEnvio({super.key, required this.estado, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cores = CoresDaObra.de(context);
    final situacao = descreverEnvio(estado, DateTime.now());
    final (icone, cor, fundo) = switch (situacao.tipo) {
      TipoDaSituacao.tudoEnviado => (
          Icons.cloud_done_outlined,
          cores.enviado,
          cores.fundoEnviado
        ),
      TipoDaSituacao.aguardando => (
          Icons.cloud_upload_outlined,
          cores.pendente,
          cores.fundoPendente
        ),
      TipoDaSituacao.recusado => (
          Icons.cloud_off_outlined,
          cores.parada,
          cores.fundoParada
        ),
      TipoDaSituacao.enviando || TipoDaSituacao.contando => (
          Icons.cloud_sync_outlined,
          cores.neutro,
          cores.fundoNeutro
        ),
    };

    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              if (situacao.tipo == TipoDaSituacao.enviando)
                SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(strokeWidth: 2.4, color: cor),
                )
              else
                Icon(icone, color: cor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      situacao.titulo,
                      style: TextStyle(
                        color: cor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      situacao.detalhe,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cor, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cor),
            ],
          ),
        ),
      ),
    );
  }
}
