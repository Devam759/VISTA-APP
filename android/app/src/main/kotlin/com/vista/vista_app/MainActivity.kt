package com.vista.vista_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.ashish.vista.jklu/debug_token"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getDebugToken") {
                // Return a clear message so the user knows where to find the token.
                // The Firebase App Check Debug token is printed by the SDK itself to Logcat.
                result.success("Check Logcat (tag: 'DebugAppCheckProvider') for your Firebase App Check token.")
            } else {
                result.notImplemented()
            }
        }
    }
}
