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
      return screenSize.y * 0.18; // Taller in landscape for better visibility
    } else {
      return screenSize.y * 0.12;
    }
  }
  
  // Get UI margins optimized for landscape
  static double getUIMargin(Vector2 screenSize) {
    if (isLandscape(screenSize)) {
      return responsive(15.0, screenSize); // Larger margins in landscape
    } else {
      return responsive(10.0, screenSize);
    }
  }
  
  // Get player safe zone for landscape
  static Vector2 getPlayerSafeZone(Vector2 screenSize) {
    if (isLandscape(screenSize)) {
      // In landscape, avoid UI areas on sides
      return Vector2(
        screenSize.x * 0.15, // 15% margin from left
        screenSize.y * 0.25, // 25% margin from top (header area)
      );
    } else {
      return Vector2(
        screenSize.x * 0.05, // 5% margin from left
        screenSize.y * 0.15, // 15% margin from top
      );
    }
  }
  
  // Check if we need compact UI for landscape
  static bool needsCompactUI(Vector2 screenSize) {
    return isLandscape(screenSize) && screenSize.y < 600;
  }

  // Get safe content area considering UI overlays in landscape
  static Vector2 getSafeContentArea(Vector2 screenSize) {
    if (isLandscape(screenSize)) {
      // Reserve space for header and bottom UI in landscape
      return Vector2(
        screenSize.x - (getUIMargin(screenSize) * 2),
        screenSize.y - getHeaderHeight(screenSize) - responsive(80.0, screenSize),
      );
    } else {
      return Vector2(
        screenSize.x - (getUIMargin(screenSize) * 2),
        screenSize.y - getHeaderHeight(screenSize) - responsive(100.0, screenSize),
      );
    }
  }

  // Get maximum dialog height for landscape compatibility
  static double getMaxDialogHeight(Vector2 screenSize) {
    if (isLandscape(screenSize)) {
      return screenSize.y * 0.8; // Leave 20% margin in landscape
    } else {
      return screenSize.y * 0.9; // Leave 10% margin in portrait
    }
  }
}