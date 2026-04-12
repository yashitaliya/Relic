import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

class ClassificationService {
  static Future<String?> analyzeImage(
      AssetEntity asset, Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;

    // Metadata-level check
    final meta = _checkMetadata(asset);
    if (meta != null) return meta;

    // Pixel analysis
    return analyzePixels(bytes);
  }

  static String? _checkMetadata(AssetEntity asset) {
    final path = (asset.relativePath ?? '').toLowerCase();
    final title = (asset.title ?? '').toLowerCase();

    // Check for selfies via path or potentially camera lens direction if available
    if (path.contains("selfie") ||
        title.contains("selfie") ||
        path.contains("front_camera")) {
      return "Selfies";
    }

    // Ignore purely functional folders
    if (path.contains("screenshot") ||
        path.contains("whatsapp") ||
        path.contains("download")) {
      return null;
    }
    return null;
  }

  static String? analyzePixels(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final int width = image.width;
    final int height = image.height;

    // Counters
    int pixelCount = 0;
    int whitePixels = 0;
    double totalLuminance = 0;

    // Voting Buckets
    int greenPixels = 0; // For Nature
    int bluePixelsTop = 0; // For Sky (only count top 35%)
    int topPixelsCount = 0;

    // Sampling Step (Increase to 10 or 15 if performance is slow)
    const int step = 8;

    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        final pixel = image.getPixel(x, y);

        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // 1. Calculate Luminance (standard formula)
        final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        totalLuminance += lum;

        // 2. White Check (High R, G, B)
        if (r > 210 && g > 210 && b > 210) {
          whitePixels++;
        }

        // 3. Convert to HSL for Color categorization
        // Custom lightweight RGB to HSL conversion
        final hsl = _rgbToHsl(r, g, b);
        final double hue = hsl[0]; // 0 - 360
        final double saturation = hsl[1]; // 0.0 - 1.0
        // lightness is roughly similar to luminance, skipping

        // --- NATURE CHECK ---
        // Green Hue: ~75 to 165 degrees
        // Must have some saturation (not grey/black)
        if (hue >= 75 && hue <= 165 && saturation > 0.25) {
          greenPixels++;
        }

        // --- SKY CHECK ---
        // Only look at the top 35% of the image
        if (y < height * 0.35) {
          topPixelsCount++;
          // Blue Hue: ~195 to 255 degrees
          // Sky usually has moderate saturation, not super intense
          if (hue >= 190 && hue <= 260 && saturation > 0.15) {
            bluePixelsTop++;
          }
        }

        pixelCount++;
      }
    }

    if (pixelCount == 0) return null;

    final avgLuminance = totalLuminance / pixelCount;
    final whiteRatio = whitePixels / pixelCount;

    // === CLASSIFICATION RULES ===

    // 1. Night (Darkness check remains the same)
    if (avgLuminance < 0.30) return "Night";

    // 2. Documents (White dominance check remains the same)
    if (whiteRatio > 0.55) return "Documents";

    // 3. Sky
    // If > 40% of the top 1/3rd of the image is Blue
    if (topPixelsCount > 0) {
      double blueTopRatio = bluePixelsTop / topPixelsCount;
      if (blueTopRatio > 0.40) return "Sky";
    }

    // 4. Nature
    // If > 25% of the TOTAL image is Green pixels
    double greenRatio = greenPixels / pixelCount;
    if (greenRatio > 0.25) return "Nature";

    // 5. Food - REMOVED as per user request

    return null; // Unclassified
  }

  // Helper: Manual RGB to HSL conversion (0-360 hue, 0-1 sat)
  static List<double> _rgbToHsl(int r, int g, int b) {
    double rf = r / 255.0;
    double gf = g / 255.0;
    double bf = b / 255.0;

    double max = math.max(rf, math.max(gf, bf));
    double min = math.min(rf, math.min(gf, bf));
    double delta = max - min;

    double h = 0;
    double s = 0;
    double l = (max + min) / 2;

    if (delta != 0) {
      s = l < 0.5 ? delta / (max + min) : delta / (2 - max - min);

      if (max == rf) {
        h = (gf - bf) / delta + (gf < bf ? 6 : 0);
      } else if (max == gf) {
        h = (bf - rf) / delta + 2;
      } else {
        h = (rf - gf) / delta + 4;
      }
      h /= 6;
    }

    return [h * 360, s, l];
  }
}
