import 'package:flutter/material.dart';

class ViveDurations {
  ViveDurations._();

  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 500);

  static const defaultCurve = Curves.easeOutCubic;
}
