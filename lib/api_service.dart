import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Replace with your actual backend URL.
  // For Android Emulator, use 'http://10.0.2.2:5000/upload'
  // For iOS Simulator, use 'http://localhost:5000/upload'
  // For Physical Device, use your computer's local IP address e.g. 'http://192.168.1.5:5000/upload'
  static const String _baseUrl = 'http://34.39.173.82/api/verify-fire';

  Future<bool> uploadMedia({
    required File? imageFile,
    required String? audioPath,
    String deviceName = "SensorNode1", // Default, can be dynamic
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));

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
