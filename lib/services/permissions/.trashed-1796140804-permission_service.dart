import 'package:permission_handler/permission_handler.dart' as ph;

/// Runtime permission helpers with clear results.
class PermissionService {
  /// null = permanently denied (needs app settings), true/false otherwise.
  Future<bool?> requestMicrophone() async {
    final status = await ph.Permission.microphone.request();
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) return null;
    return false;
  }

  Future<bool> hasMicrophone() => ph.Permission.microphone.isGranted;

  Future<bool?> requestNotifications() async {
    final status = await ph.Permission.notification.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return null;
    return false;
  }

  /// Opens this app's system settings page.
  /// (Previously this method called itself and would recurse forever.)
  Future<void> openAppSettings() => ph.openAppSettings();
}
