import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageProcessor {
  /// Decodes and re-encodes the image as JPEG, stripping all EXIF/metadata.
  /// Returns a new [File] in the app's temp directory.
  static Future<File> stripMetadata(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode image.');
    }

    final stripped = img.encodeJpg(decoded, quality: 92);
    final dir = await getTemporaryDirectory();
    final filename = 'resolara_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File(p.join(dir.path, filename));
    await dest.writeAsBytes(stripped);
    return dest;
  }

  /// Returns true if the file extension is an accepted image type.
  static bool isAcceptedType(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.heic', '.heif', '.webp'].contains(ext);
  }
}
