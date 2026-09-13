import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

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
        backgroundColor: Colors.transparent,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.white,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.white,
        ),
      ),
    );
  }
}
