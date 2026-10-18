package com.douglastkaiser.stones

import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stones/invitations")
            .setMethodCallHandler { call, result ->
                if (call.method != "share") {
                    result.notImplemented()
                } else {
                    val url = call.argument<String>("url")
                    if (url == null || !Regex("https://www\\.douglastkaiser\\.com/stones/\\?room=([UH][A-Z]{6}|[A-Z0-9]{6})").matches(url)) {
                        result.error("invalid-invitation", "Not a Stones room invitation", null)
                    } else {
                        try {
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, url)
                            }
                            startActivity(Intent.createChooser(send, "Invite to Stones"))
                            result.success(true)
                        } catch (_: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                }
            }
    }
}
