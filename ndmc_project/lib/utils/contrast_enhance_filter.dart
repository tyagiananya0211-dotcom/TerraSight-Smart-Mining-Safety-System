import 'package:flutter/material.dart';

class ContrastEnhanceFilter {
  // Adaptive Histogram Equalization (CLAHE) proxy using luminance and contrast boost
  static const List<double> grayscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  static Widget apply(Widget child) {
    // High contrast boost to simulate localized equalization
    const double contrast = 2.0;
    const double translation = (1.0 - contrast) * 128.0;
    
    const List<double> contrastMatrix = [
      contrast, 0, 0, 0, translation,
      0, contrast, 0, 0, translation,
      0, 0, contrast, 0, translation,
      0, 0, 0, 1, 0,
    ];

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(grayscaleMatrix),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(contrastMatrix),
        child: child,
      ),
    );
  }
}
