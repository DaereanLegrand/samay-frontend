import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Samay disco theme — built on the design tokens with the full
/// component-theme set (DESIGN.md §5/§6).
///
/// Contract: `docs/design/DESIGN.md` (§1–§4). Palette and
/// ThemeExtension live in `lib/core/design_tokens/app_colors.dart`
/// ([AppColors] + [SamayThemeExtension]) — the single source of
/// colors. Typography (roles + glow) lives in
/// `lib/core/design_tokens/app_typography.dart` ([AppTypography]).
/// This file only composes them into a `ThemeData`.
class SamayTheme {
  SamayTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.discoBlack,
      primaryColor: AppColors.white,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.white,
        onPrimary: AppColors.discoBlack,
        secondary: AppColors.white,
        onSecondary: AppColors.discoBlack,
        surface: AppColors.discoBlack,
        onSurface: AppColors.white,
      ),
      fontFamily: AppTypography.inter,
      // Design doc §3.3 type scale — fully owned by
      // [AppTypography.textTheme]. Display roles are Playfair Display
      // bold (rendered verbatim/white through VDisplayText); body/UI voices
      // stay light Inter per the MVP spec. Roles outside the §3.3 table
      // (titleSmall, caption, overline) keep the Material defaults merged by
      // `ThemeData`.
      textTheme: AppTypography.textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.discoBlack,
        foregroundColor: AppColors.white,
      ),
      // The app has no bottom navigation. This block is retained for the
      // Material default: it only paints if a `BottomNavigationBar` is ever
      // used. `withValues` is not const → this block drops `const` (same as
      // the inputDecorationTheme below); value equality of `SamayTheme.dark`
      // is preserved (pinned by the theme equality test).
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.85),
        selectedItemColor: AppColors.white,
        // Design doc §2.1/§2.4: `muted #666666` is the unselected-nav-icon
        // color (3.66:1 ≥ the 3:1 non-text rule).
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: false,
        showSelectedLabels: false,
      ),
      // Component themes — §2 surfaces + §4.2 sharp + §5 specs
      //
      // Values are token-only (black/white/grey/pink); corners are sharp
      // (`AppRadius.sharp`); borders are hairline `#1A1A1A` or `border
      // #333333`; M3 surface tints are stripped (flat black per §1 P2).
      // Widgets that style themselves explicitly (VButton/VChip/VInput/
      // VCard, showAppError) keep their own values — these themes govern
      // raw Material components and future screens.
      snackBarTheme: const SnackBarThemeData(
        // §2.1 `surface` is the overlay fill; snackbars are overlays.
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      ),
      dialogTheme: const DialogThemeData(
        // §1 P1 "black always … every sheet, every dialog".
        backgroundColor: AppColors.discoBlack,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      ),
      // iOS swipe-back on every pushed route
      // `CupertinoPageTransitionsBuilder` gives the native left-to-right
      // edge-swipe back gesture. Applied on every
      // platform so the iPhone-17-Pro focus carries everywhere. The const
      // builders map keeps `SamayTheme.dark == SamayTheme.dark` (const
      // canonicalization → value equality, pinned by the equality test).
      // ANIM-ON: [StaticPageTransitionsBuilder] renders routes
      // with the Cupertino swipe, suppressed only under OS-level reduced
      // motion (`disableAnimations` — the app-wide forced override was
      // removed from `SamayApp`).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: StaticPageTransitionsBuilder(),
          TargetPlatform.android: StaticPageTransitionsBuilder(),
          TargetPlatform.macOS: StaticPageTransitionsBuilder(),
          TargetPlatform.linux: StaticPageTransitionsBuilder(),
          TargetPlatform.windows: StaticPageTransitionsBuilder(),
          // The 6th platform value — covered too so no route ever falls
          // back to the Zoom builder.
          TargetPlatform.fuchsia: StaticPageTransitionsBuilder(),
        },
      ),
      // User override: borderless inputs — NO border, NO
      // background, placeholder-only. Raw Material TextFields inherit this;
      // `VInput` hardcodes the same treatment (`v_input.dart`).
      inputDecorationTheme: const InputDecorationThemeData(
        filled: false,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: TextStyle(color: AppColors.muted),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        errorStyle: TextStyle(color: AppColors.error),
      ),
      // §5.3 cards: `surface` fill over black, hairline 1px border, sharp.
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sharp,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      // §5.4 chips: transparent, 1px white border, white label; selected =
      // white fill + black label; sharp; no checkmark.
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.transparent,
        selectedColor: AppColors.white,
        labelStyle: TextStyle(color: AppColors.white),
        secondaryLabelStyle: TextStyle(color: AppColors.discoBlack),
        side: BorderSide(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sharp),
        showCheckmark: false,
      ),
      // Segmented pickers: the same
      // §5.4 chip treatment — transparent + white unselected, white fill +
      // black text selected, white side, sharp. `SegmentedButton.styleFrom`
      // builds `WidgetStateProperty.fromMap` state maps (value-equal), so
      // this keeps `SamayTheme.dark == SamayTheme.dark` value-equal. Do NOT
      // switch it to `resolveWith` (state maps must stay value-equal, or the
      // theme equality breaks).
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.transparent,
          foregroundColor: AppColors.white,
          selectedBackgroundColor: AppColors.white,
          selectedForegroundColor: AppColors.discoBlack,
          side: const BorderSide(color: AppColors.white),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.sharp,
          ),
        ),
      ),
      // §2.1 `hairline` is the divider color ("Card borders, dividers
      // (decorative)").
      dividerTheme: const DividerThemeData(color: AppColors.hairline),
      // §5.1 buttons: white label, `muted` disabled (inactive = exempt from
      // contrast), sharp. Press feedback = α0.1 white overlay — passed as
      // the base color so `TextButton.styleFrom` derives the per-state
      // alphas (pressed α0.1 / hover α0.08 / focused α0.1).
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.muted,
          overlayColor: AppColors.white,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sharp),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      // Checkboxes: selected = white fill + black check (matches the
      // colorScheme roles the M3 defaults already resolve to); unselected
      // stays border-only; sharp per §4.2. Deliberate simplification: a
      // disabled+selected box keeps the white fill (palette has no gray
      // tinted fill — the palette is §2-exact).
      // NOTE: built via `WidgetStateProperty.fromMap`, NOT `resolveWith` —
      // closures hash by identity and would break `SamayTheme.dark ==
      // SamayTheme.dark` (ThemeData value equality; pinned by the theme
      // persistence tests).
      checkboxTheme: const CheckboxThemeData(
        fillColor: WidgetStateProperty.fromMap({
          WidgetState.selected: AppColors.white,
        }),
        checkColor: WidgetStatePropertyAll(AppColors.discoBlack),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      ),
      // Sliders (Events-tab distance filter): white active track + thumb over a
      // `border` inactive track; disabled states fall back to `muted`/`surfaceAlt`.
      // Token-only and const so `SamayTheme.dark` keeps value equality.
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.white,
        thumbColor: AppColors.white,
        inactiveTrackColor: AppColors.border,
        disabledActiveTrackColor: AppColors.border,
        disabledInactiveTrackColor: AppColors.surfaceAlt,
        disabledThumbColor: AppColors.muted,
        trackHeight: 2,
      ),
      // TabBar: white indicator + white label. `unselectedLabelColor` and
      // `labelStyle` are deliberately left to the M3 defaults — §2.4 bans
      // `muted` for small informational text (3.66:1 < 4.5:1), and the
      // default onSurfaceVariant label keeps AA.
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.white,
        labelColor: AppColors.white,
      ),
      // Popup menus: black surface, white text/icons, sharp.
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.discoBlack,
        surfaceTintColor: AppColors.transparent,
        textStyle: TextStyle(color: AppColors.white),
        iconColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      ),
      // Date picker: black surface + header, white header text, sharp.
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.discoBlack,
        surfaceTintColor: AppColors.transparent,
        headerBackgroundColor: AppColors.discoBlack,
        headerForegroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      ),
      // §5.8: full-screen loading is WHITE (pink is brand-moment only —
      // welcome/checkout), and the theme default matches the current
      // colorScheme.primary rendering for raw spinners.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.white,
      ),
      // Tooltips: dark raised surface (`surfaceAlt` — §2.1 "sheets, menus"),
      // white text, sharp.
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadius.sharp,
        ),
        textStyle: TextStyle(color: AppColors.white),
      ),
      extensions: const [SamayThemeExtension.dark],
    );
  }
}

/// Page transition that renders routes STATICALLY under OS-level reduced
/// motion (`MediaQuery.disableAnimationsOf`) and otherwise delegates to the
/// Cupertino swipe.
class StaticPageTransitionsBuilder extends PageTransitionsBuilder {
  const StaticPageTransitionsBuilder();

  static const CupertinoPageTransitionsBuilder _fallback =
      CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _fallback.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
