import 'package:flame/components.dart';

class ScreenUtils {
  // Base design dimensions (phone in portrait)
  static const double baseWidth = 400.0;
  static const double baseHeight = 800.0;
  
  // Calculate responsive scale factor
  static double getScaleFactor(Vector2 screenSize) {
    final widthScale = screenSize.x / baseWidth;
    final heightScale = screenSize.y / baseHeight;
    
    // Use the smaller scale to ensure everything fits
    return (widthScale < heightScale) ? widthScale : heightScale;
  }
  
  // Get responsive size
  static double responsive(double size, Vector2 screenSize) {
    return size * getScaleFactor(screenSize);
  }
  
  // Check if device is in landscape mode
  static bool isLandscape(Vector2 screenSize) {
    return screenSize.x > screenSize.y;
  }
  
  // Check if screen is tablet-sized
  static bool isTablet(Vector2 screenSize) {
    final diagonal = screenSize.length;
    return diagonal > 1000; // Rough tablet detection
  }
  
  // Get safe margins for different screen sizes
  static double getMargin(Vector2 screenSize) {
    if (isTablet(screenSize)) {
      return responsive(20.0, screenSize);
    } else {
      return responsive(10.0, screenSize);
    }
  }
  
  // Get header height based on screen size
  static double getHeaderHeight(Vector2 screenSize) {
    if (isLandscape(screenSize)) {
      return screenSize.y * 0.15; // Slightly taller in landscape
    } else {
      return screenSize.y * 0.12;
    }
  }
}