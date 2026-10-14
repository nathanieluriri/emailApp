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
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import androidx.core.graphics.ColorUtils
import androidx.core.graphics.drawable.IconCompat
import org.json.JSONObject

object MailNotifications {
    const val CHANNEL = "mail"
    const val ACTION_ARCHIVE = "quirepost.ARCHIVE"
    const val ACTION_READ = "quirepost.READ"
    const val ACTION_REPLY = "quirepost.REPLY"
    const val ACTION_COMPOSE = "quirepost.COMPOSE"
    const val KEY_TEXT = "text"

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
        val digest = data.optString("kind") == "unread"

        builder
            .setChannelId(CHANNEL)
            .setCategory(NotificationCompat.CATEGORY_EMAIL)
            .setColor(accent(context))
            .setLargeIcon(if (digest) null else avatar(context, latest.from))
            .setContentTitle(if (digest) subject else latest.from)
            .setContentText(if (digest) lines.map { it.from }.distinct().joinToString(", ") else subject)
            .setSubText(if (data.optInt("reminder") == 1) "Unread · $account" else account)
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
            .setStyle(
                when {
                    digest -> unread(subject, lines, data.optInt("more"))
                    lines.size > 1 -> conversation(context, subject, lines)
                    else -> letter(subject, latest.text)
                },
            )

        // Only new mail carries a token, so reactions and test pushes get no buttons.
        if (data.has("token")) {
            builder.addAction(quick(context, "Archive", ACTION_ARCHIVE, NotificationCompat.Action.SEMANTIC_ACTION_ARCHIVE, id, data))
            builder.addAction(quick(context, "Mark as read", ACTION_READ, NotificationCompat.Action.SEMANTIC_ACTION_MARK_AS_READ, id, data))
            builder.addAction(reply(context, id, data))
        }
        return builder
    }

    // Replaces a notification whose inline reply failed, keeping what was typed; a tap opens it in the composer.
    fun replyFailed(context: Context, id: Int, extras: Intent, text: String) {
        val compose = Intent(context, MainActivity::class.java)
            .setAction(ACTION_COMPOSE)
            .setData(Uri.parse("quirepost://notification/$id/$ACTION_COMPOSE"))
            .putExtras(extras)
            .putExtra(KEY_TEXT, text)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_onesignal_default)
            .setColor(accent(context))
            .setContentTitle("Reply not sent")
            .setContentText(text)
            .setSubText(extras.getStringExtra("account"))
            .setStyle(NotificationCompat.BigTextStyle().bigText("Tap to send it from Quirepost.\n\n$text"))
            .setSilent(true)
            .setAutoCancel(true)
            .setContentIntent(PendingIntent.getActivity(context, id, compose, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(id, notification) }
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

    // Unread mail from several conversations: who wrote, in bold, then the subject.
    private fun unread(title: String, lines: List<Line>, more: Int): NotificationCompat.Style {
        val style = NotificationCompat.InboxStyle().setBigContentTitle(title)
        for (line in lines) {
            style.addLine(SpannableStringBuilder().append(line.from, StyleSpan(Typeface.BOLD), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE).append("  ").append(line.text))
        }
        if (more > 0) style.setSummaryText("+$more more")
        return style
    }

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

    private fun quick(context: Context, title: String, action: String, semantic: Int, id: Int, data: JSONObject) =
        NotificationCompat.Action.Builder(R.drawable.ic_stat_onesignal_default, title, broadcast(context, action, id, data, mutable = false))
            .setSemanticAction(semantic)
            .setShowsUserInterface(false)
            .build()

    // Phones that suggest replies (Android 10 and later) add them as chips above the reply field.
    private fun reply(context: Context, id: Int, data: JSONObject) =
        NotificationCompat.Action.Builder(R.drawable.ic_stat_onesignal_default, "Reply", broadcast(context, ACTION_REPLY, id, data, mutable = true))
            .addRemoteInput(RemoteInput.Builder(KEY_TEXT).setLabel("Reply").build())
            .setAllowGeneratedReplies(true)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setShowsUserInterface(false)
            .build()

    // The reply's PendingIntent must be mutable so the system can attach the typed text.
    private fun broadcast(context: Context, action: String, id: Int, data: JSONObject, mutable: Boolean): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id,
            intent(context, MailActionReceiver::class.java, action, id, data),
            PendingIntent.FLAG_UPDATE_CURRENT or if (mutable) PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_IMMUTABLE,
        )

    private fun intent(context: Context, target: Class<*>, action: String, id: Int, data: JSONObject) =
        Intent(context, target)
            .setAction(action)
            .setData(Uri.parse("quirepost://notification/$id/$action"))
            .putExtra("id", id)
            .putExtra("host", data.optString("host"))
            .putExtra("account", data.optString("account"))
            .putExtra("threadId", data.optString("threadId"))
            .putExtra("messageId", data.optString("messageId"))
            .putExtra("token", data.optString("token"))
}
