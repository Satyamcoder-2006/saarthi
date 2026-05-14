import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Headings (Poppins)
  static TextStyle displayLg = GoogleFonts.poppins(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );
  
  static TextStyle screenTitle = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static TextStyle headingBold = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static TextStyle headingMedium = GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  // Body (Noto Sans)
  static TextStyle bodyLarge = GoogleFonts.notoSans(
    fontSize: 20,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );
  
  static TextStyle bodyLargeBold = GoogleFonts.notoSans(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static TextStyle bodyMedium = GoogleFonts.notoSans(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );
  
  static TextStyle bodySmall = GoogleFonts.notoSans(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textMuted,
  );

  // Button Labels (Noto Sans)
  static TextStyle buttonLabel = GoogleFonts.notoSans(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
  );
}
