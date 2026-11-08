import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('window')
external JSObject get _window;

class WebPushBridge {
  static JSObject? get _helper {
    final val = _window.getProperty('_escalaPwaPush'.toJS);
    if (val == null || val.isUndefinedOrNull) return null;
    return val as JSObject;
  }

  static bool get isIos {
    try {
      final res = _helper?.callMethod<JSBoolean?>('isIos'.toJS);
      return res?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool get isStandalone {
    try {
      final res = _helper?.callMethod<JSBoolean?>('isStandalone'.toJS);
      return res?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool get supportsPush {
    try {
      final res = _helper?.callMethod<JSBoolean?>('supportsPush'.toJS);
      return res?.toDart ?? false;
    } catch (_) {
      return false;
    }
  }

  static String get permissionStatus {
    try {
      final res = _helper?.callMethod<JSString?>('getPermission'.toJS);
      return res?.toDart ?? 'default';
    } catch (_) {
      return 'default';
    }
  }

  static Future<bool> ensureFirebaseSwReady() async {
    try {
      final promise =
          _helper?.callMethod<JSPromise<JSBoolean>?>('ensureFirebaseSwReady'.toJS);
      if (promise == null) return false;
      final res = await promise.toDart;
      return res.toDart;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> showForegroundNotification(
    String title,
    String body,
  ) async {
    try {
      final promise = _helper?.callMethod<JSPromise<JSBoolean>?>(
        'showForegroundNotification'.toJS,
        title.toJS,
        body.toJS,
      );
      if (promise == null) return false;
      final res = await promise.toDart;
      return res.toDart;
    } catch (_) {
      return false;
    }
  }
}

