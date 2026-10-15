package ng.bridgewoodinvestment.bridgewood_mail

import android.content.Intent
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

private const val QUIRE = "ng.com.uriri.quire"

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var launch: Map<String, String?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MailNotifications.createChannel(this)
        launch = composeOf(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quirepost/notifications").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeLaunch" -> result.success(launch).also { launch = null }
                    "chime" -> {
                        MailNotifications.chime(this@MainActivity)
                        result.success(null)
                    }
                    "deviceId" -> result.success(deviceId())
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quirepost/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "pdfPage" -> {
                    val path = call.argument<String>("path")
                    val width = call.argument<Int>("width") ?: 720
                    Thread {
                        val png = path?.let { runCatching { FilePreviews.pdfPage(it, width) }.getOrNull() }
                        runOnUiThread { result.success(png) }
                    }.start()
                }
                "quireInstalled" -> result.success(packageManager.getLaunchIntentForPackage(QUIRE) != null)
                "openInQuire" -> result.success(openInQuire(call.argument<String>("path")!!, call.argument<String>("type")!!))
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        composeOf(intent)?.let { channel?.invokeMethod("launch", it) }
    }

    private fun openInQuire(path: String, type: String): Boolean {
        val uri = FileProvider.getUriForFile(this, "$packageName.files", File(path))
        val view = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, type)
            .setPackage(QUIRE)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { startActivity(view) }.isSuccess
    }

    // ANDROID_ID is fixed per device and signing key, so a reinstall keeps the same OneSignal user.
    private fun deviceId(): String? {
        val id = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        if (id.isNullOrBlank()) return null
        val hash = MessageDigest.getInstance("SHA-256").digest("quirepost:$id".toByteArray())
        return "android-" + hash.take(16).joinToString("") { "%02x".format(it) }
    }

    // Opened from a notification whose inline reply failed: finish the reply in the composer.
    private fun composeOf(intent: Intent?): Map<String, String?>? {
        if (intent?.action != MailNotifications.ACTION_COMPOSE) return null
        intent.action = Intent.ACTION_MAIN
        return mapOf(
            "action" to "reply",
            "host" to intent.getStringExtra("host"),
            "account" to intent.getStringExtra("account"),
            "threadId" to intent.getStringExtra("threadId"),
            "messageId" to intent.getStringExtra("messageId"),
            "text" to intent.getStringExtra(MailNotifications.KEY_TEXT),
        )
    }
}
