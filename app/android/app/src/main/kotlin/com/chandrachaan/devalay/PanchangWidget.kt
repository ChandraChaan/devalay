package com.chandrachaan.devalay

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home-screen card with today's Panchang. The app writes the coming weeks' lines (already in the
 * user's language) as JSON keyed by date, so the widget turns over at midnight on its own and keeps
 * working offline even when the app has not been opened for days.
 */
class PanchangWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val day = try {
            JSONObject(widgetData.getString("panchang_days", null) ?: "{}").optJSONObject(today)
        } catch (e: Exception) {
            null
        }
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.panchang_widget).apply {
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("devalay://calendar")),
                )
                if (day == null) {
                    setTextViewText(R.id.widget_day, "")
                    setTextViewText(R.id.widget_weekday, "Devalay")
                    setTextViewText(R.id.widget_month, "")
                    setTextViewText(R.id.widget_tithi, widgetData.getString("panchang_empty", "Open Devalay to load today's Panchang"))
                    listOf(R.id.widget_star, R.id.widget_rahu, R.id.widget_festival).forEach { setViewVisibility(it, View.GONE) }
                } else {
                    setTextViewText(R.id.widget_day, day.optString("day"))
                    setTextViewText(R.id.widget_weekday, day.optString("weekday"))
                    setTextViewText(R.id.widget_month, day.optString("month"))
                    setTextViewText(R.id.widget_tithi, day.optString("tithi"))
                    show(this, R.id.widget_star, day.optString("star"))
                    show(this, R.id.widget_rahu, day.optString("rahu"))
                    show(this, R.id.widget_festival, day.optString("festival"))
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun show(views: RemoteViews, id: Int, text: String) {
        views.setTextViewText(id, text)
        views.setViewVisibility(id, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }
}
