package ng.bridgewoodinvestment.bridgewood_mail

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var launch: Map<String, String?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MailNotifications.createChannel(this)
        launch = replyOf(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quirepost/notifications").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeLaunch" -> result.success(launch).also { launch = null }
                    "chime" -> {
                        MailNotifications.chime(this@MainActivity)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        replyOf(intent)?.let { channel?.invokeMethod("launch", it) }
    }

    private fun replyOf(intent: Intent?): Map<String, String?>? {
        if (intent?.action != MailNotifications.ACTION_REPLY) return null
        MailNotifications.dismiss(this, intent.getIntExtra("id", 0))
        intent.action = Intent.ACTION_MAIN
        return mapOf(
            "action" to "reply",
            "host" to intent.getStringExtra("host"),
            "threadId" to intent.getStringExtra("threadId"),
            "messageId" to intent.getStringExtra("messageId"),
        )
    }
}
