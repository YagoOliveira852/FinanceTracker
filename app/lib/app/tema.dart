import 'package:flutter/material.dart';

/// Tokens do design system "Finanças pessoais" (Claude Design), claro e escuro.
///
/// As cores do Material 3 vão no [ColorScheme]; as do domínio (receita,
/// despesa, rascunho, ritmo) vão em [CoresFinancas], lidas nas telas com
/// `Theme.of(context).extension<CoresFinancas>()!` ou `context.cores`.

/// Espaçamentos (`space-1` a `space-12`).
abstract final class Espaco {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
}

/// Raios dos cantos: chip, campo, card e bottom sheet.
abstract final class Raio {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
}

/// Algarismos de mesma largura nos valores, para alinharem na lista.
const algarismosTabulares = [FontFeature.tabularFigures()];

const _fonte = 'Manrope';

/// Cores do domínio que o Material não tem.
@immutable
class CoresFinancas extends ThemeExtension<CoresFinancas> {
  const CoresFinancas({
    required this.receita,
    required this.receitaContainer,
    required this.despesa,
    required this.despesaContainer,
    required this.rascunho,
    required this.rascunhoContainer,
    required this.ritmoOk,
    required this.ritmoOkContainer,
    required this.ritmoAtencao,
    required this.ritmoAtencaoContainer,
    required this.ritmoRisco,
    required this.ritmoRiscoContainer,
  });

  final Color receita;
  final Color receitaContainer;
  final Color despesa;
  final Color despesaContainer;
  final Color rascunho;
  final Color rascunhoContainer;
  final Color ritmoOk;
  final Color ritmoOkContainer;
  final Color ritmoAtencao;
  final Color ritmoAtencaoContainer;
  final Color ritmoRisco;
  final Color ritmoRiscoContainer;

  static const claro = CoresFinancas(
    receita: Color(0xFF1B6B45),
    receitaContainer: Color(0xFFD3EDDE),
    despesa: Color(0xFF97491F),
    despesaContainer: Color(0xFFF6E1D6),
    rascunho: Color(0xFF5A4D99),
    rascunhoContainer: Color(0xFFECE9F6),
    ritmoOk: Color(0xFF2A6A3C),
    ritmoOkContainer: Color(0xFFD7ECD9),
    ritmoAtencao: Color(0xFF7A5300),
    ritmoAtencaoContainer: Color(0xFFFAE6B3),
    ritmoRisco: Color(0xFFB3261E),
    ritmoRiscoContainer: Color(0xFFF9DEDA),
  );

  static const escuro = CoresFinancas(
    receita: Color(0xFF7DD3A2),
    receitaContainer: Color(0xFF133F2A),
    despesa: Color(0xFFF0A57B),
    despesaContainer: Color(0xFF4A2716),
    rascunho: Color(0xFFC8BEF5),
    rascunhoContainer: Color(0xFF2E2852),
    ritmoOk: Color(0xFF8FD49F),
    ritmoOkContainer: Color(0xFF173D22),
    ritmoAtencao: Color(0xFFF2C66B),
    ritmoAtencaoContainer: Color(0xFF45330A),
    ritmoRisco: Color(0xFFFFB4AB),
    ritmoRiscoContainer: Color(0xFF5C1714),
  );

  @override
  CoresFinancas copyWith() => this;

  @override
  CoresFinancas lerp(CoresFinancas? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return CoresFinancas(
      receita: c(receita, other.receita),
      receitaContainer: c(receitaContainer, other.receitaContainer),
      despesa: c(despesa, other.despesa),
      despesaContainer: c(despesaContainer, other.despesaContainer),
      rascunho: c(rascunho, other.rascunho),
      rascunhoContainer: c(rascunhoContainer, other.rascunhoContainer),
      ritmoOk: c(ritmoOk, other.ritmoOk),
      ritmoOkContainer: c(ritmoOkContainer, other.ritmoOkContainer),
      ritmoAtencao: c(ritmoAtencao, other.ritmoAtencao),
      ritmoAtencaoContainer: c(
        ritmoAtencaoContainer,
        other.ritmoAtencaoContainer,
      ),
      ritmoRisco: c(ritmoRisco, other.ritmoRisco),
      ritmoRiscoContainer: c(ritmoRiscoContainer, other.ritmoRiscoContainer),
    );
  }
}

extension TemaNoContexto on BuildContext {
  ThemeData get tema => Theme.of(this);
  ColorScheme get esquema => Theme.of(this).colorScheme;
  TextTheme get textos => Theme.of(this).textTheme;
  CoresFinancas get cores => Theme.of(this).extension<CoresFinancas>()!;
}

const _esquemaClaro = ColorScheme(
  brightness: Brightness.light,
  surface: Color(0xFFF6F5F1),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFEEEDE8),
  surfaceContainerHigh: Color(0xFFE6E5DF),
  onSurface: Color(0xFF1B201F),
  onSurfaceVariant: Color(0xFF545E5B),
  outline: Color(0xFF737D79),
  outlineVariant: Color(0xFFD9DBD5),
  primary: Color(0xFF1F5F66),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFCDE8E8),
  onPrimaryContainer: Color(0xFF0B3539),
  secondary: Color(0xFF4E615D),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDCE6E2),
  onSecondaryContainer: Color(0xFF1C2B28),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDA),
  onErrorContainer: Color(0xFFB3261E),
);

const _esquemaEscuro = ColorScheme(
  brightness: Brightness.dark,
  surface: Color(0xFF111514),
  surfaceContainerLow: Color(0xFF181D1C),
  surfaceContainer: Color(0xFF1E2423),
  surfaceContainerHigh: Color(0xFF272D2C),
  onSurface: Color(0xFFE3E7E4),
  onSurfaceVariant: Color(0xFFA9B3AF),
  outline: Color(0xFF8A9490),
  outlineVariant: Color(0xFF343B39),
  primary: Color(0xFF86D0D6),
  onPrimary: Color(0xFF00363B),
  primaryContainer: Color(0xFF134C52),
  onPrimaryContainer: Color(0xFFC9EEF0),
  secondary: Color(0xFFB4CAC5),
  onSecondary: Color(0xFF1F3330),
  secondaryContainer: Color(0xFF364A46),
  onSecondaryContainer: Color(0xFFD0E6E1),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF5C1714),
  onErrorContainer: Color(0xFFFFB4AB),
);

ThemeData temaClaro() => _tema(_esquemaClaro, CoresFinancas.claro);

ThemeData temaEscuro() => _tema(_esquemaEscuro, CoresFinancas.escuro);

/// Escala tipográfica do design system (display, headline, title, body, label,
/// caption) nos papéis do Material 3.
TextTheme _textos(Color cor, Color corVariante) {
  TextStyle estilo(
    double tamanho,
    double altura,
    FontWeight peso, {
    double espacamento = 0,
    Color? corDoTexto,
  }) => TextStyle(
    fontFamily: _fonte,
    fontSize: tamanho,
    height: altura / tamanho,
    fontWeight: peso,
    letterSpacing: espacamento,
    color: corDoTexto ?? cor,
  );

  final caption = estilo(
    12,
    16,
    FontWeight.w500,
    espacamento: 0.2,
    corDoTexto: corVariante,
  );
  return TextTheme(
    displaySmall: estilo(40, 48, FontWeight.w700, espacamento: -0.5),
    headlineMedium: estilo(28, 36, FontWeight.w700, espacamento: -0.25),
    titleLarge: estilo(20, 28, FontWeight.w600),
    titleMedium: estilo(16, 24, FontWeight.w600),
    bodyLarge: estilo(16, 24, FontWeight.w400),
    bodyMedium: estilo(14, 20, FontWeight.w400),
    labelLarge: estilo(14, 20, FontWeight.w600, espacamento: 0.1),
    labelMedium: estilo(12, 16, FontWeight.w600, espacamento: 0.2),
    bodySmall: caption,
    labelSmall: caption,
  );
}

ThemeData _tema(ColorScheme esquema, CoresFinancas cores) {
  final textos = _textos(esquema.onSurface, esquema.onSurfaceVariant);
  const forma = StadiumBorder();
  const tamanhoBotao = Size(64, 48);
  final bordaCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Raio.md),
    borderSide: BorderSide(color: esquema.outline),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: _fonte,
    textTheme: textos,
    scaffoldBackgroundColor: esquema.surface,
    extensions: [cores],
    appBarTheme: AppBarTheme(
      backgroundColor: esquema.surface,
      foregroundColor: esquema.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleTextStyle: textos.titleLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: tamanhoBotao,
        padding: const EdgeInsets.symmetric(horizontal: Espaco.x6),
        shape: forma,
        textStyle: textos.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: tamanhoBotao,
        padding: const EdgeInsets.symmetric(horizontal: Espaco.x6),
        shape: forma,
        side: BorderSide(color: esquema.outline),
        textStyle: textos.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: tamanhoBotao,
        shape: forma,
        textStyle: textos.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: esquema.primary,
      foregroundColor: esquema.onPrimary,
      extendedTextStyle: textos.labelLarge,
      shape: forma,
      elevation: 6,
    ),
    inputDecorationTheme: InputDecorationTheme(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Espaco.x4,
        vertical: Espaco.x4,
      ),
      border: bordaCampo,
      enabledBorder: bordaCampo,
      focusedBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: esquema.primary, width: 2),
      ),
      errorBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: esquema.error, width: 2),
      ),
      focusedErrorBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: esquema.error, width: 2),
      ),
      disabledBorder: bordaCampo.copyWith(
        borderSide: BorderSide(
          color: esquema.onSurface.withValues(alpha: 0.12),
        ),
      ),
      labelStyle: textos.bodySmall,
      floatingLabelStyle: textos.bodySmall,
      helperStyle: textos.bodySmall?.copyWith(fontWeight: FontWeight.w400),
      errorStyle: textos.bodySmall?.copyWith(
        color: esquema.error,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: textos.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
      prefixStyle: textos.bodyLarge?.copyWith(color: esquema.onSurfaceVariant),
      helperMaxLines: 2,
      errorMaxLines: 2,
    ),
    cardTheme: CardThemeData(
      color: esquema.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: esquema.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: esquema.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        textos.labelMedium?.copyWith(color: esquema.onSurface),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: esquema.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
