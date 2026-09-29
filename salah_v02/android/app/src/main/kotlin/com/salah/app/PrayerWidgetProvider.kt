package com.salah.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar

class PrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("prayer_widget", Context.MODE_PRIVATE)
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            views.setTextViewText(R.id.widget_city, prefs.getString("city", "Salah"))
            views.setTextViewText(R.id.widget_next_name, prefs.getString("nextName", "Sonraki Namaz"))
            views.setTextViewText(R.id.widget_next_time, prefs.getString("nextTime", "--:--"))
            val nextTime = prefs.getString("nextTime", "--:--") ?: "--:--"
            val parts = nextTime.split(":")
            val remaining = if (parts.size >= 2) {
                val now = Calendar.getInstance()
                val target = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, parts[0].toIntOrNull() ?: 0)
                    set(Calendar.MINUTE, parts[1].toIntOrNull() ?: 0)
                    set(Calendar.SECOND, 0)
                    if (!after(now)) add(Calendar.DAY_OF_MONTH, 1)
                }
                val minutes = ((target.timeInMillis - now.timeInMillis) / 60000).coerceAtLeast(0)
                "Kalan: %02d:%02d".format(minutes / 60, minutes % 60)
            } else { "" }
            views.setTextViewText(R.id.widget_remaining, remaining)
            views.setTextViewText(R.id.widget_times, prefs.getString("times", ""))
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
