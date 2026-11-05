import 'package:flutter/material.dart';

/// 医疗记录风格：白色底 + 蓝色主色，强调清晰、紧凑、不好看但好用。
const Color kInk = Color(0xFF1F2D3D);
const Color kInkSoft = Color(0xFF6B7A8C);
const Color kBg = Color(0xFFF3F6F9);
const Color kCard = Color(0xFFFFFFFF);
const Color kPrimary = Color(0xFF1D6FA5);
const Color kPrimarySoft = Color(0xFFE2F0F8);
const Color kDivider = Color(0xFFDDE5EC);
const Color kDanger = Color(0xFFC0392B);
const Color kInvasive = Color(0xFF1D6FA5); // 有创：蓝
const Color kNiv = Color(0xFF2E8B6E); // 无创：绿

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      brightness: Brightness.light,
    ).copyWith(primary: kPrimary),
  );
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: kInk,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: kInk,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: kPrimary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
    ),
    dividerTheme: const DividerThemeData(color: kDivider, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kDivider),
      ),
      labelStyle: const TextStyle(fontSize: 12, color: kInkSoft),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFA9B6C4)),
      filled: true,
      fillColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
