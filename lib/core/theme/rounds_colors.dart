import 'package:flutter/material.dart';

/// Design tokens layered on top of the two hand-picked [ColorScheme]s.
///
/// The scheme stays the navy identity; these are the semantic colors the
/// redesign added: the paid/overdue status pair and the two named
/// de-emphasis steps that replace the ad-hoc `withValues(alpha: ...)`
/// values that used to be improvised per widget.
class RoundsColors extends ThemeExtension<RoundsColors> {
  const RoundsColors({
    required this.paid,
    required this.paidContainer,
    required this.overdueSurface,
    required this.overdueBorder,
    required this.neutralDot,
    required this.textSecondary,
    required this.textFaint,
  });

  /// Settled state — the only green in the app.
  final Color paid;

  /// Tinted circle behind a paid check mark.
  final Color paidContainer;

  /// Card surface for overdue bills, tinted so urgency reads before text does.
  final Color overdueSurface;
  final Color overdueBorder;

  /// Eyebrow dot for the pending section — quieter than primary.
  final Color neutralDot;

  /// De-emphasis steps: secondary for subtitles, faint for metadata.
  final Color textSecondary;
  final Color textFaint;

  static const light = RoundsColors(
    paid: Color(0xFF27AE60),
    paidContainer: Color(0x2227AE60),
    overdueSurface: Color(0xFFFBEAE7),
    overdueBorder: Color(0xFFECCBC6),
    neutralDot: Color(0xFF8FB4CC),
    textSecondary: Color(0xA61A2B3C),
    textFaint: Color(0x731A2B3C),
  );

  static const dark = RoundsColors(
    paid: Color(0xFF3DCE8C),
    paidContainer: Color(0x293DCE8C),
    overdueSurface: Color(0xFF252230),
    overdueBorder: Color(0x48FF897D),
    neutralDot: Color(0xFF3A5D80),
    textSecondary: Color(0xA6E4EEFA),
    textFaint: Color(0x73E4EEFA),
  );

  static RoundsColors of(BuildContext context) =>
      Theme.of(context).extension<RoundsColors>()!;

  @override
  RoundsColors copyWith({
    Color? paid,
    Color? paidContainer,
    Color? overdueSurface,
    Color? overdueBorder,
    Color? neutralDot,
    Color? textSecondary,
    Color? textFaint,
  }) {
    return RoundsColors(
      paid: paid ?? this.paid,
      paidContainer: paidContainer ?? this.paidContainer,
      overdueSurface: overdueSurface ?? this.overdueSurface,
      overdueBorder: overdueBorder ?? this.overdueBorder,
      neutralDot: neutralDot ?? this.neutralDot,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
    );
  }

  @override
  RoundsColors lerp(RoundsColors? other, double t) {
    if (other == null) return this;
    return RoundsColors(
      paid: Color.lerp(paid, other.paid, t)!,
      paidContainer: Color.lerp(paidContainer, other.paidContainer, t)!,
      overdueSurface: Color.lerp(overdueSurface, other.overdueSurface, t)!,
      overdueBorder: Color.lerp(overdueBorder, other.overdueBorder, t)!,
      neutralDot: Color.lerp(neutralDot, other.neutralDot, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
    );
  }
}
