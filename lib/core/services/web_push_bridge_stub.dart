class WebPushBridge {
  static bool get isIos => false;
  static bool get isStandalone => true;
  static bool get supportsPush => true;
  static String get permissionStatus => 'granted';

  static Future<bool> ensureFirebaseSwReady() async => true;

  static Future<bool> showForegroundNotification(
    String title,
    String body,
  ) async =>
      false;
}

