package ng.bridgewoodinvestment.bridgewood_mail

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.RemoteInput
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MailActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        val id = intent.getIntExtra("id", 0)
        val action = when (intent.action) {
            MailNotifications.ACTION_ARCHIVE -> "archive"
            MailNotifications.ACTION_REPLY -> "reply"
            else -> "read"
        }
        val text = RemoteInput.getResultsFromIntent(intent)?.getCharSequence(MailNotifications.KEY_TEXT)?.toString()?.trim().orEmpty()
        if (action == "reply" && text.isEmpty()) return
        // A reply keeps its notification, showing the system's sending spinner, until the worker has it.
        if (action != "reply") MailNotifications.dismiss(app, id)
        val pending = goAsync()
        thread {
            val body = JSONObject().put("token", intent.getStringExtra("token")).put("address", intent.getStringExtra("account"))
            if (action == "reply") body.put("text", text).put("messageId", intent.getStringExtra("messageId"))
            val done = runCatching { post(intent, action, body) }.getOrDefault(false)
            when {
                action == "reply" && done -> MailNotifications.dismiss(app, id)
                action == "reply" -> MailNotifications.replyFailed(app, id, intent, text)
                !done -> Handler(Looper.getMainLooper()).post {
                    val what = if (action == "archive") "archive" else "mark as read"
                    Toast.makeText(app, "Couldn't $what. Open Quirepost to try again.", Toast.LENGTH_LONG).show()
                }
            }
            pending.finish()
        }
    }

    private fun post(intent: Intent, action: String, body: JSONObject): Boolean {
        val thread = Uri.encode(intent.getStringExtra("threadId"))
        val connection = (URL("https://${intent.getStringExtra("host")}/actions/$thread/$action").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 20_000
            doOutput = true
            setRequestProperty("content-type", "application/json")
        }
        connection.outputStream.use { it.write(body.toString().toByteArray()) }
        return connection.responseCode.also { connection.disconnect() } in 200..299
    }
}
