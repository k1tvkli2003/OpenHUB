import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const background = Color(0xFF0A131B);
  static const surface = Color(0xFF0E1922);
  static const surfaceRaised = Color(0xFF12202B);
  static const surfaceStrong = Color(0xFF182833);
  static const outline = Color(0xFF263C49);
  static const outlineStrong = Color(0xFF385567);
  static const cyan = Color(0xFF2AD7E5);
  static const green = Color(0xFF43D17A);
  static const amber = Color(0xFFFFB020);
  static const red = Color(0xFFFF636B);
  static const text = Color(0xFFF4F7FA);
  static const textMuted = Color(0xFFA3B0BC);
}

abstract final class AppRadii {
  static const small = 5.0;
  static const control = 6.0;
  static const panel = 7.0;
  static const feature = 10.0;
}

ThemeData buildAppTheme() {
  final scheme = const ColorScheme.dark(
    primary: AppPalette.cyan,
    onPrimary: Color(0xFF041013),
    secondary: AppPalette.green,
    onSecondary: Color(0xFF04120B),
    error: AppPalette.red,
    onError: Color(0xFF1B0508),
    surface: AppPalette.surface,
    onSurface: AppPalette.text,
    outline: AppPalette.outline,
    outlineVariant: AppPalette.outlineStrong,
  );

  const baseText = TextTheme(
    displaySmall: TextStyle(
      color: AppPalette.text,
      fontSize: 34,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.05,
    ),
    headlineMedium: TextStyle(
      color: AppPalette.text,
      fontSize: 28,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.7,
    ),
    titleLarge: TextStyle(
      color: AppPalette.text,
      fontSize: 18,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.18,
    ),
    titleMedium: TextStyle(
      color: AppPalette.text,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(color: AppPalette.text, fontSize: 15, height: 1.5),
    bodyMedium: TextStyle(
      color: AppPalette.textMuted,
      fontSize: 13.5,
      height: 1.48,
    ),
    bodySmall: TextStyle(
      color: AppPalette.textMuted,
      fontSize: 12,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      color: AppPalette.text,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.08,
    ),
  );

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.control),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppPalette.background,
    canvasColor: AppPalette.background,
    cardColor: AppPalette.surface,
    dividerColor: AppPalette.outline,
    disabledColor: AppPalette.textMuted.withValues(alpha: 0.4),
    fontFamily: 'Segoe UI Variable',
    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    splashFactory: InkSparkle.splashFactory,
    textTheme: baseText,
    iconTheme: const IconThemeData(color: AppPalette.textMuted, size: 20),
    cardTheme: CardThemeData(
      color: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: const BorderSide(color: AppPalette.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        shape: controlShape,
        textStyle: baseText.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        side: const BorderSide(color: AppPalette.outlineStrong),
        shape: controlShape,
        textStyle: baseText.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        shape: controlShape,
        textStyle: baseText.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppPalette.cyan.withValues(alpha: 0.14),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppPalette.text
              : AppPalette.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppPalette.cyan
              : AppPalette.textMuted,
          size: 20,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppPalette.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppPalette.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppPalette.cyan, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        borderSide: const BorderSide(color: AppPalette.red),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(controlShape),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppPalette.outlineStrong),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppPalette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.feature),
        side: const BorderSide(color: AppPalette.outline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppPalette.surfaceStrong,
      contentTextStyle: baseText.bodyMedium?.copyWith(color: AppPalette.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        side: const BorderSide(color: AppPalette.outlineStrong),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppPalette.surfaceStrong,
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: AppPalette.outlineStrong),
      ),
      textStyle: const TextStyle(color: AppPalette.text, fontSize: 12),
      waitDuration: const Duration(milliseconds: 350),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(999),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.hovered)
            ? AppPalette.outlineStrong
            : AppPalette.outline;
      }),
    ),
  );
}

class OpenHubMark extends StatelessWidget {
  const OpenHubMark({this.size = 28, this.visualScale = 1.16, super.key});

  final double size;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'OpenHUB Prismatic Gate',
      child: ClipRect(
        child: SizedBox.square(
          dimension: size,
          child: Transform.scale(
            scale: visualScale,
            child: Image.asset(
              'assets/brand/openhub-route-hub.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}

class OpenHubWordmark extends StatelessWidget {
  const OpenHubWordmark({this.height = 24, this.excludeFromSemantics = false, super.key});

  final double height;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/openhub-wordmark.png',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      gaplessPlayback: true,
      semanticLabel: excludeFromSemantics ? null : 'OpenHUB',
      excludeFromSemantics: excludeFromSemantics,
    );
  }
}

class OpenHubBrandLockup extends StatelessWidget {
  const OpenHubBrandLockup({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const Tooltip(
        message: 'OpenHUB · Local account router',
        child: OpenHubMark(size: 44),
      );
    }
    return Semantics(
      header: true,
      label: 'OpenHUB, local account router',
      child: Row(
        children: <Widget>[
          const OpenHubMark(size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const OpenHubWordmark(
                  height: 24,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: 3),
                const Text(
                  'Local account router',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
