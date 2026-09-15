import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colours for states Material has no role for.
///
/// `ColorScheme` covers primary/error/surface, but not "this pass is cached
/// offline", "this seat is held by you", or "the QR is suppressed for clock
/// drift". Those are the states this product is actually about, so they live
/// here as a [ThemeExtension] rather than as literals in feature widgets.
///
/// Read them through `context.semantic` — see `BuildContextX`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.dangerContainer,
    required this.seatAvailable,
    required this.seatHeld,
    required this.seatSold,
    required this.seatConflict,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.surfaceElevated,
    required this.border,
    required this.borderStrong,
    required this.qrCanvas,
    required this.qrInk,
  });

  /// The dark palette — the only one the design defines.
  const AppSemanticColors.dark()
    : warning = AppColors.warning,
      onWarning = AppColors.onPrimary,
      warningContainer = AppColors.warningSoft,
      success = AppColors.success,
      onSuccess = AppColors.onPrimary,
      successContainer = AppColors.successSoft,
      dangerContainer = AppColors.dangerSoft,
      seatAvailable = AppColors.borderStrong,
      seatHeld = AppColors.primary,
      seatSold = AppColors.textDisabled,
      seatConflict = AppColors.danger,
      textSecondary = AppColors.textSecondary,
      textTertiary = AppColors.textTertiary,
      textDisabled = AppColors.textDisabled,
      surfaceElevated = AppColors.surfaceElevated,
      border = AppColors.border,
      borderStrong = AppColors.borderStrong,
      qrCanvas = AppColors.qrCanvas,
      qrInk = AppColors.qrInk;

  /// Degraded but usable: offline, locked sector, clock drift, screenshot
  /// intercepted.
  final Color warning;
  final Color onWarning;
  final Color warningContainer;

  /// Confirmed and live: purchase complete, pass active, seat held.
  final Color success;
  final Color onSuccess;
  final Color successContainer;

  /// Tinted background behind an error banner.
  final Color dangerContainer;

  /// Seat-map states. Named for what they mean, so the seat widget never
  /// decides what "taken" looks like.
  final Color seatAvailable;
  final Color seatHeld;
  final Color seatSold;
  final Color seatConflict;

  /// Text ramp below `onSurface`.
  final Color textSecondary;
  final Color textTertiary;

  /// Placeholders and disabled labels — the dimmest readable step.
  final Color textDisabled;

  /// A surface one step above the card — nested panels, sheets.
  final Color surfaceElevated;

  final Color border;
  final Color borderStrong;

  /// The white QR card and its ink. Fixed regardless of theme: a scanner
  /// needs dark modules on a light field.
  final Color qrCanvas;
  final Color qrInk;

  @override
  AppSemanticColors copyWith({
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? dangerContainer,
    Color? seatAvailable,
    Color? seatHeld,
    Color? seatSold,
    Color? seatConflict,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? surfaceElevated,
    Color? border,
    Color? borderStrong,
    Color? qrCanvas,
    Color? qrInk,
  }) {
    return AppSemanticColors(
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      seatAvailable: seatAvailable ?? this.seatAvailable,
      seatHeld: seatHeld ?? this.seatHeld,
      seatSold: seatSold ?? this.seatSold,
      seatConflict: seatConflict ?? this.seatConflict,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      qrCanvas: qrCanvas ?? this.qrCanvas,
      qrInk: qrInk ?? this.qrInk,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) return this;
    return AppSemanticColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      seatAvailable: Color.lerp(seatAvailable, other.seatAvailable, t)!,
      seatHeld: Color.lerp(seatHeld, other.seatHeld, t)!,
      seatSold: Color.lerp(seatSold, other.seatSold, t)!,
      seatConflict: Color.lerp(seatConflict, other.seatConflict, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      qrCanvas: Color.lerp(qrCanvas, other.qrCanvas, t)!,
      qrInk: Color.lerp(qrInk, other.qrInk, t)!,
    );
  }
}
