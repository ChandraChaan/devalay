package com.chandrachaan.devalay

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** 2×1 card: today's date and tithi, with a mark on festival and family days. Reads PanchangWidget's data. */
class TithiWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val key = WidgetSupport.dateKey()
        val day = WidgetSupport.json(widgetData, "panchang_days").optJSONObject(key)
        for (id in appWidgetIds) {
            val views = WidgetSupport.responsive(context, appWidgetManager, id, 90) { compact ->
                RemoteViews(context.packageName, R.layout.tithi_widget).apply {
                    setOnClickPendingIntent(R.id.tithi_root, WidgetSupport.open(context, "devalay://calendar/day/$key"))
                    if (day == null) {
                        setTextViewText(R.id.tithi_date, "Devalay")
                        setTextViewText(R.id.tithi_mark, "🛕")
                        setTextViewText(R.id.tithi_name, WidgetSupport.label(widgetData, "empty", "Open Devalay"))
                        setInt(R.id.tithi_name, "setMaxLines", 2)
                        setViewVisibility(R.id.tithi_festival, View.GONE)
                    } else {
                        val mark = day.optString("mark")
                        val text = day.optString("mark_text")
                        setTextViewText(R.id.tithi_date, day.optString("date_short"))
                        setTextViewText(R.id.tithi_mark, mark)
                        setTextViewText(R.id.tithi_name, day.optString("tithi"))
                        setTextViewText(R.id.tithi_festival, text)
                        setViewVisibility(R.id.tithi_festival, if (compact || text.isEmpty()) View.GONE else View.VISIBLE)
                    }
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        super.onAppWidgetOptionsChanged(context, manager, id, options)
        onUpdate(context, manager, intArrayOf(id))
    }
}
