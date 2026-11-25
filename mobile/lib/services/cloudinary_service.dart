import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/services/api_service.dart';

class CloudinaryService {
  static const int maxUploadBytes = 10 * 1024 * 1024;

  /// Sends image bytes only to the authenticated Spring API. Cloudinary credentials
  /// and signatures remain on the server for both Flutter Web and Android.
  static Future<String> uploadImageXFile(XFile xfile) async {
    final size = await xfile.length();
    if (size <= 0) {
      throw const FormatException('El archivo seleccionado está vacío.');
    }
    if (size > maxUploadBytes) {
      throw const FormatException('La imagen no puede superar 10 MB.');
    }

    final bytes = await xfile.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxUploadBytes) {
      throw const FormatException('El archivo seleccionado no es válido o excede 10 MB.');
    }

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: xfile.name,
          contentType: DioMediaType('application', 'octet-stream'),
        ),
      });
      final response = await ApiService().dio.post('/files/upload', data: formData);
      final data = response.data;
      if (data is! Map || data['url'] is! String ||
          (data['url'] as String).isEmpty || data['publicId'] is! String) {
        throw const FormatException('El servidor no confirmó la carga de la imagen.');
      }
      return data['url'] as String;
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map && responseData['message'] is String
          ? responseData['message'] as String
          : 'No se pudo subir la imagen. Intenta nuevamente.';
      throw Exception(message);
    }
  }

  static Future<List<String>> uploadMultipleXFiles(List<XFile> xfiles) async {
    final urls = <String>[];
    for (final xfile in xfiles) {
      urls.add(await uploadImageXFile(xfile));
    }
    return urls;
  }
}
