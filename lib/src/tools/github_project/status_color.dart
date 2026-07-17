import 'package:flutter/material.dart';

/// GitHub status option color enum -> mid-tone color readable on light and
/// dark backgrounds. Mirrors the macOS menu bar app's mapping.
Color statusColor(String? enumName) => switch (enumName) {
      'GRAY' => const Color(0xFF8C949E),
      'BLUE' => const Color(0xFF549CF5),
      'GREEN' => const Color(0xFF57AB5A),
      'YELLOW' => const Color(0xFFD9AB40),
      'ORANGE' => const Color(0xFFE0823D),
      'RED' => const Color(0xFFE6544A),
      'PINK' => const Color(0xFFE375AE),
      'PURPLE' => const Color(0xFF996EE3),
      _ => const Color(0xFFD1D6DE),
    };
