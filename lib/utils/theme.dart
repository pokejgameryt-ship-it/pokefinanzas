import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primaryColor = Color(0xFF2E7D32);
  static const Color _secondaryColor = Color(0xFF1565C0);
  static const Color _tertiaryColor = Color(0xFFE65100);
  static const Color _errorColor = Color(0xFFD32F2F);
  static const Color _incomeColor = Color(0xFF4CAF50);
  static const Color _expenseColor = Color(0xFFF44336);
  static const Color _savingsColor = Color(0xFF2196F3);

  static Color get incomeColor => _incomeColor;
  static Color get expenseColor => _expenseColor;
  static Color get savingsColor => _savingsColor;

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
      secondary: _secondaryColor,
      tertiary: _tertiaryColor,
      error: _errorColor,
    );

    return _baseTheme(colorScheme);
  }

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
      secondary: _secondaryColor,
      tertiary: _tertiaryColor,
      error: _errorColor,
    );

    return _baseTheme(colorScheme);
  }

  static ThemeData _baseTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const SlideUpPageTransitionBuilder(),
          TargetPlatform.iOS: const SlideUpPageTransitionBuilder(),
          TargetPlatform.windows: const SlideUpPageTransitionBuilder(),
          TargetPlatform.macOS: const SlideUpPageTransitionBuilder(),
          TargetPlatform.linux: const SlideUpPageTransitionBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: const CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            );
          }
          return TextStyle(color: colorScheme.onSurfaceVariant);
        }),
      ),
    );
  }
}

class SlideUpPageTransitionBuilder extends PageTransitionsBuilder {
  const SlideUpPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final tween = Tween(begin: const Offset(0, 0.05), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic));
    final fadeTween = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut));

    return SlideTransition(
      position: animation.drive(tween),
      child: FadeTransition(
        opacity: animation.drive(fadeTween),
        child: child,
      ),
    );
  }
}
