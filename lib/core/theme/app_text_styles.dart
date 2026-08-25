import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Text styles matching the Rubik weights actually used on the approved
/// production screens (the Design System page specifies Inter — the live
/// screens use Rubik, and the live screens win).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _rubik(
    double size,
    FontWeight weight, {
    Color? color,
    double? height,
  }) {
    return GoogleFonts.rubik(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      height: height,
    );
  }

  static TextStyle heroTitle = _rubik(46, FontWeight.w900); // Rubik Black
  static TextStyle screenTitle = _rubik(28, FontWeight.w800); // ExtraBold
  static TextStyle screenTitleBlack = _rubik(30, FontWeight.w900);
  static TextStyle subtitle = _rubik(
    14,
    FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  static TextStyle subtitleLg = _rubik(
    16,
    FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle cardTitle = _rubik(15, FontWeight.w700);
  static TextStyle cardTitleLg = _rubik(16, FontWeight.w700);
  static TextStyle cardSubtitle = _rubik(
    12,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle cardSubtitleMd = _rubik(
    13,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle buttonLabel = _rubik(16, FontWeight.w700);
  static TextStyle chipLabel = _rubik(
    14,
    FontWeight.w500,
    color: AppColors.textSecondary,
  );
  static TextStyle chipLabelSelected = _rubik(
    14,
    FontWeight.w700,
    color: AppColors.onSelected,
  );

  static TextStyle fieldLabel = _rubik(14, FontWeight.w600);
  static TextStyle fieldValue = _rubik(14, FontWeight.w400);
  static TextStyle fieldPlaceholder = _rubik(
    14,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle caption = _rubik(
    12,
    FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static TextStyle captionBold = _rubik(13, FontWeight.w700);
}
