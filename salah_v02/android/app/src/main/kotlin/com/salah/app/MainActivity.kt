package com.salah.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.salah.app/prayer_widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method == "updatePrayerWidget") {
                val args = call.arguments as? Map<*, *> ?: emptyMap<String, String>()
                val prefs = getSharedPreferences("prayer_widget", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("city", args["city"]?.toString() ?: "")
                    .putString("nextName", args["nextName"]?.toString() ?: "Namaz")
                    .putString("nextTime", args["nextTime"]?.toString() ?: "--:--")
                    .putString("remaining", args["remaining"]?.toString() ?: "")
                    .putString("times", args["times"]?.toString() ?: "")
                    .apply()
                val manager = AppWidgetManager.getInstance(this)
                val component = ComponentName(this, PrayerWidgetProvider::class.java)
                val ids = manager.getAppWidgetIds(component)
                val intent = Intent(this, PrayerWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                sendBroadcast(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
