import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Dark luxury" theme: near-black surfaces, neon lime + gold accents,
/// glassy cards and a geometric numeric face for money figures.
class AppTheme {
  AppTheme._();

  // ===== BRAND COLORS =====
  static const Color primaryColor = Color(0xFFC6F24E); // neon lime
  static const Color primaryDark = Color(0xFF9BC53D);
  static const Color primaryLight = Color(0xFFDDFB8C);
  static const Color onPrimary = Color(0xFF0A0B0D);
  static const Color goldColor = Color(0xFFE8C468);
  static const Color violetColor = Color(0xFFA78BFA);

  // ===== SEMANTIC COLORS =====
  static const Color accentColor = Color(0xFF2DD4BF);
  static const Color successColor = Color(0xFF34D399);
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color errorColor = Color(0xFFFB7185);
  static const Color infoColor = Color(0xFF60A5FA);

  // ===== GRADIENTS =====
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE2FC8F), Color(0xFFB4E33D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF6DE9A), Color(0xFFC99A3B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deep graphite used for hero areas; pair with [glowBlob]s for the neon glow.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1C2112), Color(0xFF111316), Color(0xFF0C0D10)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFB45309)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFBE123C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFFC4B5FD), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF5EEAD4), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = accentGradient;

  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF93C5FD), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===== SURFACES (the app is dark-only; light names kept for old call sites) =====
  static const Color darkBackground = Color(0xFF09090B);
  static const Color darkSurface = Color(0xFF111215);
  static const Color darkCard = Color(0xFF16181C);
  static const Color darkBorder = Color(0xFF26292F);
  static const Color darkTextPrimary = Color(0xFFF5F5F4);
  static const Color darkTextSecondary = Color(0xFF9A9FA8);

  static const Color lightBackground = darkBackground;
  static const Color lightSurface = darkSurface;
  static const Color lightCard = darkCard;
  static const Color lightBorder = darkBorder;
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;

  // ===== DECORATION HELPERS =====
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Readable foreground (near-black or white) for content drawn on [background].
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.light
          ? onPrimary
          : Colors.white;

  /// Neon glow under a colored element.
  static List<BoxShadow> softShadow(Color color, {double strength = 1}) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22 * strength),
          blurRadius: 28,
          offset: const Offset(0, 10),
          spreadRadius: -6,
        ),
      ];

  /// Standard surface card: graphite with a hairline top highlight.
  static BoxDecoration cardDecoration(
    BuildContext context, {
    double radius = 20,
    Color? color,
  }) {
    return BoxDecoration(
      color: color,
      gradient: color == null
          ? const LinearGradient(
              colors: [Color(0xFF1A1C21), Color(0xFF141519)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: -10,
        ),
      ],
    );
  }

  /// Soft radial glow used behind hero content.
  static Widget glowBlob({
    required double size,
    Color color = primaryColor,
    double opacity = 0.28,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  // ===== TYPOGRAPHY =====
  static final String? _bodyFamily = GoogleFonts.hindSiliguri().fontFamily;

  /// Geometric face for money and counts; Bangla glyphs fall back to Hind Siliguri.
  static TextStyle numeric({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.5,
    double? height,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    ).copyWith(fontFamilyFallback: [?_bodyFamily]);
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    TextStyle s(double size, FontWeight weight, Color color, {double? height}) =>
        GoogleFonts.hindSiliguri(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
        );

    return TextTheme(
      displayLarge: s(34, FontWeight.w700, primary),
      displayMedium: s(30, FontWeight.w700, primary),
      displaySmall: s(26, FontWeight.w700, primary),
      headlineLarge: s(26, FontWeight.w700, primary),
      headlineMedium: s(24, FontWeight.w700, primary),
      headlineSmall: s(19, FontWeight.w600, primary),
      titleLarge: s(17, FontWeight.w600, primary),
      titleMedium: s(15, FontWeight.w600, primary),
      titleSmall: s(14, FontWeight.w600, primary),
      bodyLarge: s(16, FontWeight.w400, primary),
      bodyMedium: s(14, FontWeight.w400, secondary),
      bodySmall: s(12, FontWeight.w400, secondary),
      labelLarge: s(14, FontWeight.w600, primary),
      labelMedium: s(12, FontWeight.w600, secondary),
      labelSmall: s(11, FontWeight.w500, secondary),
    );
  }

  static ThemeData _build() {
    const primary = primaryColor;
    const background = darkBackground;
    const surface = darkSurface;
    const card = darkCard;
    const border = darkBorder;
    const text = darkTextPrimary;
    const subtext = darkTextSecondary;
    final textTheme = _buildTextTheme(text, subtext);
    final radius12 = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: onPrimary,
        secondary: goldColor,
        onSecondary: onPrimary,
        tertiary: accentColor,
        surface: surface,
        error: errorColor,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: card,
      textTheme: textTheme,
      fontFamily: _bodyFamily,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        titleTextStyle: GoogleFonts.hindSiliguri(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius12),
        iconColor: primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: GoogleFonts.hindSiliguri(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: GoogleFonts.hindSiliguri(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          side: BorderSide(color: primary.withValues(alpha: 0.5)),
          textStyle: GoogleFonts.hindSiliguri(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F1013),
        border: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: errorColor)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: errorColor, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.hindSiliguri(color: subtext),
        floatingLabelStyle: GoogleFonts.hindSiliguri(color: primary, fontWeight: FontWeight.w600),
        hintStyle: GoogleFonts.hindSiliguri(color: subtext.withValues(alpha: 0.7)),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? primary : subtext,
        ),
        suffixIconColor: subtext,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: const Color(0xFF0E0F12),
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.hindSiliguri(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? text : subtext,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? onPrimary : subtext, size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primary,
        selectedIconTheme: const IconThemeData(color: onPrimary),
        unselectedIconTheme: const IconThemeData(color: subtext),
        selectedLabelTextStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700, color: text, fontSize: 12),
        unselectedLabelTextStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w500, color: subtext, fontSize: 12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: subtext,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.hindSiliguri(fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        titleTextStyle: GoogleFonts.hindSiliguri(fontSize: 20, fontWeight: FontWeight.w700, color: text),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F2228),
        contentTextStyle: GoogleFonts.hindSiliguri(color: text, fontSize: 14),
        actionTextColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: radius12,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, color: text),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onPrimary : subtext,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : border,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primary : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? onPrimary : text,
          ),
          side: WidgetStateProperty.all(const BorderSide(color: border)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D33),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.hindSiliguri(color: text, fontSize: 12),
      ),
    );
  }

  static ThemeData get darkTheme => _build();

  /// Same as [darkTheme]; the luxury look is dark-only.
  static ThemeData get lightTheme => _build();
}
