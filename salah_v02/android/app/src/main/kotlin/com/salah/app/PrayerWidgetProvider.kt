package com.salah.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class PrayerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("prayer_widget", Context.MODE_PRIVATE)
        for (id in ids) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            views.setTextViewText(R.id.widget_city, prefs.getString("city", "Salah"))
            views.setTextViewText(R.id.widget_next_name, prefs.getString("nextName", "Sonraki Namaz"))
            views.setTextViewText(R.id.widget_next_time, prefs.getString("nextTime", "--:--"))
            views.setTextViewText(R.id.widget_remaining, prefs.getString("remaining", "Uygulamayı açarak güncelleyin"))
            views.setTextViewText(R.id.widget_times, prefs.getString("times", ""))
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}
