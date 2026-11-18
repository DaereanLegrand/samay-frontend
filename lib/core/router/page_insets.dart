import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

/// Bottom inset for a full-screen page body.
///
/// The slim build has NO bottom navigation bar, so a page body only needs to
/// clear the OS home-indicator / gesture area. Kept as one helper (mirroring
/// the old `MainShell.navBarInset` call shape) so every screen pads its
/// scrollable by the same amount.
double pageBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + AppSpacing.md;
