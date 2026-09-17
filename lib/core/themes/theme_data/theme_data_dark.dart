import 'package:flutter/material.dart';
import '../../utils/spacing.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

ThemeData getDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,

    // ─── Color Scheme ─────────────────────────────────────────────────────
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary200,
      brightness: Brightness.dark,
      primary: AppColors.primary200,
      onPrimary: AppColors.white,
      secondary: AppColors.secondary200,
      onSecondary: AppColors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.white,
      error: AppColors.red200,
      onError: AppColors.white,
    ),

    // ─── Text ─────────────────────────────────────────────────────────────
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: AppColors.white,
          displayColor: AppColors.white,
        ),

    // ─── Elevated Button ──────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary200,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.darkSurfaceVariant,
        disabledForegroundColor: AppColors.darkTextDisabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rr(12)),
        ),
        textStyle: AppTextStyles.font16Bold,
      ),
    ),

    // ─── Text Button ──────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary200,
        textStyle: AppTextStyles.font16Bold,
      ),
    ),

    // ─── Outlined Button ──────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary200,
        side: const BorderSide(color: AppColors.primary200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rr(12)),
        ),
        textStyle: AppTextStyles.font16Bold,
      ),
    ),

    // ─── Input Decoration ─────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WidgetStateColor.resolveWith((final states) {
        if (states.contains(WidgetState.focused)) {
          return AppColors.darkSurfaceVariant;
        }
        return AppColors.darkSurface;
      }),
      hintStyle: AppTextStyles.font16Regular.copyWith(
        color: AppColors.darkTextHint,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rr(10)),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rr(10)),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rr(10)),
        borderSide: const BorderSide(color: AppColors.primary200),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rr(10)),
        borderSide: const BorderSide(color: AppColors.red200),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rr(10)),
        borderSide: const BorderSide(color: AppColors.red300),
      ),
    ),

    // ─── Card ─────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),

    // ─── Divider ──────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
    ),

    // ─── Icon ─────────────────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: AppColors.grey200),
  );
}
