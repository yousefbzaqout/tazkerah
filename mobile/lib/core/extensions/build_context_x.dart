import 'package:flutter/material.dart';

import '../../app/theme/app_semantic_colors.dart';
import '../../l10n/generated/app_localizations.dart';

/// Shorthands for the three lookups nearly every widget performs.
///
/// Saves the repetition of `Theme.of(context).colorScheme` in every build
/// method. Deliberately limited to lookups — no behaviour, nothing that hides
/// a real decision behind a getter.
extension BuildContextX on BuildContext {
  /// Localized strings.
  AppLocalizations get l10n => AppLocalizations.of(this);

  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get textStyles => Theme.of(this).textTheme;

  /// Colours for states Material has no role for — offline, seat held, clock
  /// drift. Use this instead of importing `AppColors` into a widget.
  ///
  /// Falls back to the dark tokens when the extension is missing, which
  /// happens under a bare `MaterialApp` in tests and widget previews. A crash
  /// there would be a worse failure than slightly-off colours in a harness
  /// that never renders to a user.
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ??
      const AppSemanticColors.dark();

  /// Whether the active locale is right-to-left.
  ///
  /// Prefer directional widgets and `EdgeInsetsDirectional` over branching on
  /// this. It is here for the rare case that genuinely differs — mirroring a
  /// custom-painted ticket notch, for instance.
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
}
