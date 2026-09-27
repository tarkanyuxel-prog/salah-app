package com.salah.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class DailyIslamicWidget : AppWidgetProvider() {
    private val hadiths = listOf(
        "Ameller niyetlere göredir. — Buhârî 1",
        "Kolaylaştırın, zorlaştırmayın. — Buhârî, Müslim",
        "Merhamet etmeyene merhamet olunmaz. — Buhârî, Müslim",
        "Müslüman, elinden ve dilinden insanların emin olduğu kimsedir. — Buhârî, Müslim",
        "Temizlik imanın yarısıdır. — Müslim"
    )
    private val duas = listOf(
        "Rabbimiz! Bize dünyada iyilik, ahirette de iyilik ver. — Bakara 2:201",
        "Rabbim! İlmimi artır. — Tâhâ 20:114",
        "Rabbimiz! Bizi doğru yola ilettikten sonra kalplerimizi eğriltme. — Âl-i İmrân 3:8",
        "Rabbim! Beni ve soyumdan gelecekleri namazı devamlı kılanlardan eyle. — İbrâhîm 14:40",
        "Rabbimiz! Üzerimize sabır yağdır ve ayaklarımızı sağlam tut. — Bakara 2:250"
    )

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val showHadith = prefs.getBoolean("flutter.hadith_widget", true)
        val showDua = prefs.getBoolean("flutter.dua_widget", true)
        val day = (System.currentTimeMillis() / 86_400_000L).toInt()
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.daily_islamic_widget)
            val parts = mutableListOf<String>()
            if (showHadith) parts += "Günün Hadisi\n" + hadiths[Math.floorMod(day, hadiths.size)]
            if (showDua) parts += "Günün Duası\n" + duas[Math.floorMod(day + 2, duas.size)]
            views.setTextViewText(R.id.widget_text, if (parts.isEmpty()) "Salah • Widget içeriği Ayarlar'dan açılabilir." else parts.joinToString("\n\n"))
            manager.updateAppWidget(id, views)
        }
    }
}
