import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// QR geometry on the black page (px): the code sits directly on the page and
/// is framed by a thin ring of exactly [kAttendanceQrRingWidth]. The single
/// source of truth for the attendee QR square — the live rotating code and the
/// assist out-animation both render through [AttendanceQrView], so they can
/// never drift.
const double kAttendanceQrSide = 250;
const double kAttendanceQrRingWidth = 3;

/// The plain white-module QR on the black page: transparent background, sharp
/// square modules, no tile. Sized to [kAttendanceQrSide] minus the ring band,
/// so it sits flush INSIDE the ring drawn by its parent.
class AttendanceQrView extends StatelessWidget {
  const AttendanceQrView({super.key, required this.code});

  /// The 24-hex rotating code rendered as the QR payload.
  final String code;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: kAttendanceQrSide - 2 * kAttendanceQrRingWidth,
      child: QrImageView(
        data: code,
        version: QrVersions.auto,
        padding: EdgeInsets.zero,
        backgroundColor: AppColors.transparent,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: context.palette.foreground,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: context.palette.foreground,
        ),
      ),
    );
  }
}
