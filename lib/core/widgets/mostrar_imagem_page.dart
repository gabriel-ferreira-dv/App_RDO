import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/arquivos_da_foto.dart';
import '../utils/share_util.dart';
import 'editar_imagem_page.dart';

// Exibe uma única foto em tela cheia, com ações de compartilhar e editar.
// Reaproveitada tanto pela câmera (foto recém-tirada) quanto pelo histórico
// (fotos já salvas). Foto com a original guardada pode ser vista sem carimbo.
class MostrarImagemPage extends StatefulWidget {
  final String imagePath;
  final String descricao;

  const MostrarImagemPage(
      {super.key, required this.imagePath, this.descricao = ''});

  @override
  State<MostrarImagemPage> createState() => _MostrarImagemPageState();
}

class _MostrarImagemPageState extends State<MostrarImagemPage> {
  late final String? _original = originalDaFoto(widget.imagePath);
  bool _semCarimbo = false;

  // Compartilha o que está na tela.
  String get _exibida {
    final original = _original;
    return _semCarimbo && original != null ? original : widget.imagePath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_semCarimbo ? 'Foto sem carimbo' : 'Foto'),
        actions: [
          if (_original != null)
            IconButton(
              icon: Icon(_semCarimbo ? Icons.layers : Icons.layers_clear),
              tooltip: _semCarimbo ? 'Mostrar o carimbo' : 'Ver sem carimbo',
              onPressed: () => setState(() => _semCarimbo = !_semCarimbo),
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar',
            onPressed: () =>
                compartilharImagem(_exibida, texto: widget.descricao),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      EditarImagemPage(imagePath: widget.imagePath),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(child: Image.file(File(_exibida))),
    );
  }
}
