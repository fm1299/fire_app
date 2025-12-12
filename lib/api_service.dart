import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Future<bool> uploadMedia({
    required File? imageFile,
    required String? audioPath,
    String deviceName = "SensorNode1",
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      request.fields['device_name'] = deviceName;

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      if (audioPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('audio', audioPath),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('Upload successful: ${response.body}');
        return true;
      } else {
        print('Upload failed with status: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error uploading media: $e');
      return false;
    }
  }
}
