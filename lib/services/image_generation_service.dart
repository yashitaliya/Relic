import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ImageGenerationService {
  // Using Pollinations.ai - completely free, no API key required, no limits
  static const String _baseUrl = 'https://image.pollinations.ai/prompt';

  ImageGenerationService();

  /// Generate an image from a text prompt
  /// Returns the image bytes or throws an exception on error
  Future<Uint8List> generateImage(String prompt) async {
    if (prompt.trim().isEmpty) {
      throw Exception('Prompt cannot be empty');
    }

    try {
      // URL encode the prompt
      final encodedPrompt = Uri.encodeComponent(prompt.trim());

      // Build the request URL with parameters
      // width=1024&height=1024 for square images
      // nologo=true to remove watermark
      // model=flux for high quality
      final url =
          '$_baseUrl/$encodedPrompt?width=1024&height=1024&nologo=true&enhance=true';

      debugPrint('Generating image from: $url');

      // Make the API request
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              throw Exception(
                'Request timed out. Please check your connection and try again.',
              );
            },
          );

      // Handle response
      if (response.statusCode == 200) {
        // Success - return the image bytes
        debugPrint(
          'Image generated successfully, size: ${response.bodyBytes.length} bytes',
        );
        return response.bodyBytes;
      } else {
        debugPrint('Failed with status code: ${response.statusCode}');
        throw Exception(
          'Failed to generate image. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      debugPrint('Error generating image: $e');
      throw Exception(
        'Failed to generate image. Please check your connection and try again.',
      );
    }
  }

  /// Validate that the prompt is acceptable
  bool isValidPrompt(String prompt) {
    final trimmed = prompt.trim();
    return trimmed.isNotEmpty && trimmed.length <= 1000;
  }
}
