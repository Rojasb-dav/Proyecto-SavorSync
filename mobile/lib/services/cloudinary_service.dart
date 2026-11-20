import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = 'jflzrtvk';
  static const String uploadPreset = 'foodies_unsigned';
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Subir una imagen a Cloudinary usando XFile (compatible con Web y Móvil)
  static Future<String?> uploadImageXFile(XFile xfile) async {
    try {
      final bytes = await xfile.readAsBytes();
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: xfile.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData) as Map<String, dynamic>;
        return json['secure_url'] as String?;
      } else {
        debugPrint('Error en respuesta de Cloudinary: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción al subir imagen a Cloudinary: $e');
      return null;
    }
  }

  /// Subir múltiples imágenes XFile (compatible con Web y Móvil)
  static Future<List<String>> uploadMultipleXFiles(List<XFile> xfiles) async {
    final List<String> urls = [];
    for (final xfile in xfiles) {
      final url = await uploadImageXFile(xfile);
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }
}
