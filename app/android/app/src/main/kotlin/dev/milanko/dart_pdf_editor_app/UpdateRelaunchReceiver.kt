package dev.milanko.dart_pdf_editor_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// After an update replaces the installed app, Android closes it. This tries
/// to open it again so the person is not left on the home screen. On recent
/// Android versions the system may refuse to start an activity from the
/// background; in that case nothing happens and the app is opened by hand.
class UpdateRelaunchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName) ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(launch)
        } catch (_: Exception) {
            // Blocked by the system: nothing else to do.
        }
    }
}
