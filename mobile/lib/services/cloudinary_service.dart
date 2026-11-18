import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'jflzrtvk';
  static const String uploadPreset = 'foodies_unsigned';
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Subir una imagen a Cloudinary (Modo Unsigned)
  /// Retorna la URL segura (https) enviada por Cloudinary o null si falla.
  static Future<String?> uploadImage(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

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

  /// Subir un lote de imágenes a Cloudinary (hasta 5 fotos por publicación)
  static Future<List<String>> uploadMultipleImages(List<File> files) async {
    final List<String> urls = [];
    for (final file in files) {
      final url = await uploadImage(file);
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }
}
