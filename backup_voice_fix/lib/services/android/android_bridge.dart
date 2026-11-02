import 'package:flutter/services.dart';

import '../../core/constants.dart';

/// Bridge to native Android (Kotlin) capabilities.
class AndroidBridge {
  static const _channel = MethodChannel(kBridgeChannel);

  Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestOverlayPermission() =>
      _channel.invokeMethod('requestOverlayPermission');

  /// mode: 'small' | 'large'. Large mode shows the status line + close button.
  Future<bool> showOverlay({required String mode, String status = ''}) async {
    try {
      return await _channel.invokeMethod<bool>('showOverlay',
              {'mode': mode, 'status': status}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> updateOverlayStatus(String status) =>
      _channel.invokeMethod('updateOverlayStatus', {'status': status});

  Future<void> hideOverlay() => _channel.invokeMethod('hideOverlay');

  /// Shows a notification that brings MXFF AI back and can re-show the orb.
  Future<void> showReturnNotification() =>
      _channel.invokeMethod('showReturnNotification');

  /// Opens an installed app via its launch intent (no Play Store redirect).
  /// Returns false when the app is not installed or cannot launch.
  Future<bool> openApp(String packageName) async {
    try {
      return await _channel
              .invokeMethod<bool>('openApp', {'packageName': packageName}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isAppInstalled(String packageName) async {
    try {
      return await _channel.invokeMethod<bool>(
              'isAppInstalled', {'packageName': packageName}) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Sends MXFF AI to the background (like pressing Home) while keeping the
  /// floating orb alive.
  Future<void> minimizeApp() => _channel.invokeMethod('minimizeApp');
}
