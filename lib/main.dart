import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/inicializacao.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final inicio = await inicializarApp();
  runApp(MyApp(cameras: inicio.cameras, usuarioInicial: inicio.usuario));
}
