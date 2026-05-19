import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String cloudName = 'dmfmu1vge';
  static const String uploadPreset = 'ml_default';

  Future<String?> uploadFile(Uint8List fileBytes, String fileName) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
    );

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: fileName, // Dùng tên file động
          ),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw Exception(data['error']?['message'] ?? 'Upload failed');
      }

      return data['secure_url'];
    } catch (e) {
      rethrow;
    }
  }
}
