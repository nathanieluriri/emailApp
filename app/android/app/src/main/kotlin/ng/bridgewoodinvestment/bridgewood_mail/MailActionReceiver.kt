package ng.bridgewoodinvestment.bridgewood_mail

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MailActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val archive = intent.action == MailNotifications.ACTION_ARCHIVE
        val app = context.applicationContext
        MailNotifications.dismiss(app, intent.getIntExtra("id", 0))
        val pending = goAsync()
        thread {
            val done = runCatching {
                val thread = Uri.encode(intent.getStringExtra("threadId"))
                val url = URL("https://${intent.getStringExtra("host")}/actions/$thread/${if (archive) "archive" else "read"}")
                val connection = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 15_000
                    readTimeout = 15_000
                    doOutput = true
                    setRequestProperty("content-type", "application/json")
                }
                val body = JSONObject().put("token", intent.getStringExtra("token")).put("address", intent.getStringExtra("account"))
                connection.outputStream.use { it.write(body.toString().toByteArray()) }
                connection.responseCode.also { connection.disconnect() } in 200..299
            }.getOrDefault(false)
            if (!done) {
                val what = if (archive) "archive" else "mark as read"
                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(app, "Couldn't $what. Open Quirepost to try again.", Toast.LENGTH_LONG).show()
                }
            }
            pending.finish()
        }
    }
}
