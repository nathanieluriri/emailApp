package ng.bridgewoodinvestment.bridgewood_mail

import androidx.core.app.NotificationCompat
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

class MailNotificationExtension : INotificationServiceExtension {
    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val notification = event.notification
        val data = notification.additionalData ?: return
        if (!data.has("lines")) return
        val context = event.context
        MailNotifications.createChannel(context)
        // Read the id when the extender runs: OneSignal reuses the conversation's id for a collapse key only after this callback.
        notification.setExtender(
            NotificationCompat.Extender { MailNotifications.style(context, it, notification.androidNotificationId, data) },
        )
    }
}
