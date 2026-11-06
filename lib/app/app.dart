import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/modo_do_tema.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/models/usuario.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/troca_de_senha_page.dart';
import '../features/inicio/presentation/pages/home_page.dart';

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Usuario? usuarioInicial;

  const MyApp({super.key, required this.cameras, this.usuarioInicial});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Usuario? _usuarioLogado = widget.usuarioInicial;

  void _sair() {
    AuthService.instancia.logout();
    setState(() => _usuarioLogado = null);
  }

  @override
  Widget build(BuildContext context) {
    // O botão do tema (barra do topo) troca o modo; o app inteiro redesenha.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ModoDoTema.instancia.modo,
      builder: (context, modo, _) => MaterialApp(
        title: 'RDO cbm',
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: modo,
        home: _usuarioLogado == null
            ? LoginPage(
                aoLogar: (usuario) => setState(() => _usuarioLogado = usuario))
            // Senha provisória: a troca vem antes da Home (só com internet).
            : ValueListenableBuilder<bool>(
                valueListenable: AuthService.instancia.trocaDeSenhaPendente,
                builder: (context, trocar, _) => trocar
                    ? TrocaDeSenhaPage(
                        nome: _usuarioLogado!.nome,
                        aoSair: _sair,
                      )
                    : HomePage(
                        cameras: widget.cameras,
                        usuario: AuthService.instancia.usuarioLogado ??
                            _usuarioLogado!,
                        aoSair: _sair,
                      ),
              ),
      ),
    );
  }
}
