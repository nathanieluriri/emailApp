package ng.bridgewoodinvestment.bridgewood_mail

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.StyleSpan
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.graphics.ColorUtils
import androidx.core.graphics.drawable.IconCompat
import org.json.JSONObject

object MailNotifications {
    const val CHANNEL = "mail"
    const val ACTION_ARCHIVE = "quirepost.ARCHIVE"
    const val ACTION_READ = "quirepost.READ"
    const val ACTION_REPLY = "quirepost.REPLY"

    // Same colours, order and hash as Avatar in lib/core/widgets.dart, so a sender keeps one colour everywhere.
    private val palette = longArrayOf(0xFF4285F4, 0xFF21A366, 0xFFF5C518, 0xFFE8544A, 0xFFB39DDB, 0xFFC9832B, 0xFF4F378B)
        .map { it.toInt() }

    private var inter: Typeface? = null

    private class Line(val from: String, val out: Boolean, val text: String, val at: Long)

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(CHANNEL, "New mail", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Every new email as it arrives"
            enableVibration(true)
            enableLights(true)
            lightColor = accent(context)
            setShowBadge(true)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun style(context: Context, builder: NotificationCompat.Builder, id: Int, data: JSONObject): NotificationCompat.Builder {
        val lines = data.optJSONArray("lines")?.let { list ->
            (0 until list.length()).map { list.getJSONObject(it) }.map {
                Line(it.optString("from"), it.optInt("out") == 1, it.optString("text"), it.optLong("at"))
            }
        }.orEmpty()
        val latest = lines.lastOrNull() ?: return builder
        val subject = data.optString("subject")
        val account = data.optString("account").ifEmpty { null }

        builder
            .setChannelId(CHANNEL)
            .setCategory(NotificationCompat.CATEGORY_EMAIL)
            .setColor(accent(context))
            .setLargeIcon(avatar(context, latest.from))
            .setContentTitle(latest.from)
            .setContentText(subject)
            .setSubText(account)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(
                NotificationCompat.Builder(context, CHANNEL)
                    .setSmallIcon(R.drawable.ic_stat_onesignal_default)
                    .setColor(accent(context))
                    .setContentTitle("New email")
                    .setSubText(account)
                    .build(),
            )
            .setSilent(data.optInt("quiet") == 1)
            .setStyle(if (lines.size > 1) conversation(context, subject, lines) else letter(subject, latest.text))

        if (data.has("token")) {
            builder.addAction(R.drawable.ic_stat_onesignal_default, "Archive", broadcast(context, ACTION_ARCHIVE, id, data))
            builder.addAction(R.drawable.ic_stat_onesignal_default, "Mark as read", broadcast(context, ACTION_READ, id, data))
        }
        if (data.optString("kind") == "mail") {
            val reply = intent(context, MainActivity::class.java, ACTION_REPLY, id, data).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            builder.addAction(
                R.drawable.ic_stat_onesignal_default,
                "Reply",
                PendingIntent.getActivity(context, id, reply, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
            )
        }
        return builder
    }

    fun dismiss(context: Context, id: Int) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val shown = manager.activeNotifications.firstOrNull { it.id == id }
        manager.cancel(id)
        // OneSignal's delete intent keeps its group summary and unread count in step with the shade.
        runCatching { shown?.notification?.deleteIntent?.send() }
    }

    fun chime(context: Context) {
        val sound = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(NotificationManager::class.java).getNotificationChannel(CHANNEL)
                ?.takeIf { it.importance >= NotificationManager.IMPORTANCE_DEFAULT }?.sound
        } else {
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        }
        sound?.let { RingtoneManager.getRingtone(context, it)?.play() }
    }

    private fun accent(context: Context) = Color.parseColor("#" + context.getString(R.string.onesignal_notification_accent_color))

    private fun letter(subject: String, text: String) = NotificationCompat.BigTextStyle().bigText(
        SpannableStringBuilder()
            .append(subject, StyleSpan(Typeface.BOLD), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            .append('\n')
            .append(text),
    )

    private fun conversation(context: Context, subject: String, lines: List<Line>): NotificationCompat.Style {
        val style = NotificationCompat.MessagingStyle(Person.Builder().setName("You").build())
            .setConversationTitle(subject)
            .setGroupConversation(true)
        val people = mutableMapOf<String, Person>()
        for (line in lines) {
            val sender = if (line.out) {
                null
            } else {
                people.getOrPut(line.from) {
                    Person.Builder().setName(line.from).setIcon(IconCompat.createWithBitmap(avatar(context, line.from))).build()
                }
            }
            style.addMessage(line.text, line.at, sender)
        }
        return style
    }

    private fun avatar(context: Context, name: String): Bitmap {
        val size = context.resources.getDimensionPixelSize(android.R.dimen.notification_large_icon_width)
        val fill = colorFor(name.lowercase())
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fill }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        paint.apply {
            color = if (ColorUtils.calculateLuminance(fill) > 0.35) 0xFF1C1B1F.toInt() else Color.WHITE
            textSize = size * 0.42f
            textAlign = Paint.Align.CENTER
            typeface = typeface(context)
        }
        val letter = name.trim().firstOrNull()?.uppercase() ?: "?"
        canvas.drawText(letter, size / 2f, size / 2f - (paint.descent() + paint.ascent()) / 2, paint)
        return bitmap
    }

    private fun colorFor(seed: String): Int {
        var h = 0
        for (c in seed) h = (h * 31 + c.code) and 0x7fffffff
        return palette[h % palette.size]
    }

    private fun typeface(context: Context): Typeface = inter ?: runCatching {
        Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/Inter-SemiBold.ttf")
    }.getOrDefault(Typeface.DEFAULT_BOLD).also { inter = it }

    private fun broadcast(context: Context, action: String, id: Int, data: JSONObject): PendingIntent = PendingIntent.getBroadcast(
        context,
        id,
        intent(context, MailActionReceiver::class.java, action, id, data),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun intent(context: Context, target: Class<*>, action: String, id: Int, data: JSONObject) =
        Intent(context, target)
            .setAction(action)
            .setData(Uri.parse("quirepost://notification/$id/$action"))
            .putExtra("id", id)
            .putExtra("host", data.optString("host"))
            .putExtra("threadId", data.optString("threadId"))
            .putExtra("messageId", data.optString("messageId"))
            .putExtra("token", data.optString("token"))
}
