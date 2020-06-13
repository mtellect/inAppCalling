import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<bool> cameraAndMicrophonePermissionsGranted() async {
    final camRequest = await Permission.camera.request();
    final micRequest = await Permission.microphone.request();

    if (camRequest.isGranted && micRequest.isGranted) {
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> contactPermissionGranted() async {
    final request = await Permission.contacts.request();
    if (request.isGranted) {
      return true;
    } else {
      return false;
    }
  }
}
