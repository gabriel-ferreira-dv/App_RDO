import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cores_app.dart';

export 'cores_app.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final escuro = brightness == Brightness.dark;
  final cores = escuro ? CoresDaObra.escuro : CoresDaObra.claro;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: grafite,
    brightness: brightness,
    primary: escuro ? const Color(0xFFB9C7D4) : grafite,
    onPrimary: escuro ? const Color(0xFF12181E) : Colors.white,
    secondary: amareloObra,
    onSecondary: grafite,
    secondaryContainer:
        escuro ? const Color(0xFF4A3A00) : const Color(0xFFFFE7A3),
    onSecondaryContainer:
        escuro ? const Color(0xFFFFE08A) : const Color(0xFF3B2C00),
    surface: escuro ? const Color(0xFF12181E) : const Color(0xFFF4F5F7),
  );

  final corDoCartao = escuro
      ? colorScheme.surfaceContainer
      : colorScheme.surfaceContainerLowest;
  final cantos = BorderRadius.circular(12);

  final textos =
      ThemeData(useMaterial3: true, brightness: brightness).textTheme;
  final textoDosBotoes =
      textos.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    extensions: [cores],

    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: cores.cabecalho,
      foregroundColor: cores.noCabecalho,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: textos.titleLarge!.copyWith(
        color: cores.noCabecalho,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),

    // Visual de todos os campos: preenchido, com cantos arredondados.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: escuro
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: cantos,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: cantos,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: cantos,
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: cantos,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: cantos,
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: cantos),
        textStyle: textoDosBotoes,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: cantos),
        textStyle: textoDosBotoes,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: cantos),
        side: BorderSide(color: colorScheme.outline),
        textStyle: textoDosBotoes,
      ),
    ),

    // O botão redondo do meio da barra de baixo (Registrar).
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cores.destaque,
      foregroundColor: cores.naDestaque,
      elevation: 2,
      shape: const CircleBorder(),
    ),

    bottomAppBarTheme: BottomAppBarThemeData(
      color: corDoCartao,
      elevation: 3,
      height: 68,
      padding: EdgeInsets.zero,
    ),

    cardTheme: CardThemeData(
      color: corDoCartao,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: cantos,
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: cantos),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: corDoCartao,
      showDragHandle: true,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
