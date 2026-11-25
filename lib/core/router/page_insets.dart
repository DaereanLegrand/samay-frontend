import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

/// Bottom inset for a full-screen page body.
///
/// The slim build has NO bottom navigation bar, so a page body only needs to
/// clear the OS home-indicator / gesture area. Kept as one helper so every
/// screen pads its scrollable by the same amount. (The pre-slim build had a
/// `MainShell` bottom nav with its own `navBarInset`; both are gone.)
double pageBottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + AppSpacing.md;
