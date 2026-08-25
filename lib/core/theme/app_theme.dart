import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppRadii {
  AppRadii._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 100;
}

class AppSpacing {
  AppSpacing._();
  static const double screenPadding = 24;
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgMid,
      fontFamily: AppTextStyles.subtitle.fontFamily,
      textTheme: TextTheme(bodyMedium: AppTextStyles.fieldValue),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.purple,
        surface: AppColors.cardStart,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
