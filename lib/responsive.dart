import 'package:flutter/material.dart';

/// Responsive design helper class for adaptive UI scaling
class Responsive {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double textScaleFactor;

  /// Initialize responsive values - call this in main.dart MaterialApp
  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;
    textScaleFactor = _mediaQueryData.textScaleFactor;
  }

  /// Get responsive height (percentage of screen height)
  static double getHeight(double percentage) {
    return blockSizeVertical * percentage;
  }

  /// Get responsive width (percentage of screen width)
  static double getWidth(double percentage) {
    return blockSizeHorizontal * percentage;
  }

  /// Get responsive font size
  static double getFontSize(double size) {
    return size * textScaleFactor;
  }

  /// Determine if device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Determine if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if device is mobile (width < 600)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Check if device is tablet (width >= 600 and < 1200)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  /// Check if device is desktop (width >= 1200)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  /// Get padding based on device size
  static EdgeInsets getDefaultPadding(BuildContext context) {
    if (isMobile(context)) {
      return EdgeInsets.all(Responsive.getWidth(4));
    } else if (isTablet(context)) {
      return EdgeInsets.all(Responsive.getWidth(3));
    } else {
      return EdgeInsets.all(Responsive.getWidth(2));
    }
  }

  /// Get button height based on device size
  static double getButtonHeight(BuildContext context) {
    if (isMobile(context)) {
      return Responsive.getHeight(6);
    } else {
      return Responsive.getHeight(5);
    }
  }
}

/// Extension for easier responsive calls
extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);
  
  double h(double percentage) => Responsive.getHeight(percentage);
  double w(double percentage) => Responsive.getWidth(percentage);
  double fontSize(double size) => Responsive.getFontSize(size);
}
