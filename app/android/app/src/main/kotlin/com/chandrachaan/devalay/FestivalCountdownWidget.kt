package com.chandrachaan.devalay

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.TimeUnit

/** Days left to the next major festival. The app writes the coming year's major festivals with their dates. */
class FestivalCountdownWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = WidgetSupport.dateKey()
        val list = try {
            JSONArray(widgetData.getString("countdown", null) ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }
        // Dates are "yyyy-MM-dd", so string order is date order.
        val upcoming = (0 until list.length()).mapNotNull { list.optJSONObject(it) }.filter { it.optString("date") >= today }
        val next = upcoming.firstOrNull()
        for (id in appWidgetIds) {
            val views = WidgetSupport.responsive(context, appWidgetManager, id, 100) { compact ->
                RemoteViews(context.packageName, R.layout.countdown_widget).apply {
                    setTextViewText(R.id.countdown_title, WidgetSupport.label(widgetData, "next_festival", "Next festival"))
                    setViewVisibility(R.id.countdown_title, if (compact) View.GONE else View.VISIBLE)
                    setTextViewTextSize(R.id.countdown_emoji, android.util.TypedValue.COMPLEX_UNIT_SP, if (compact) 22f else 32f)
                    if (next == null) {
                        setOnClickPendingIntent(R.id.countdown_root, WidgetSupport.open(context, "devalay://calendar"))
                        setTextViewText(R.id.countdown_emoji, "🛕")
                        setTextViewText(R.id.countdown_name, WidgetSupport.label(widgetData, "empty", "Open Devalay"))
                        setViewVisibility(R.id.countdown_days, View.GONE)
                        setViewVisibility(R.id.countdown_then, View.GONE)
                    } else {
                        val date = next.optString("date")
                        setOnClickPendingIntent(R.id.countdown_root, WidgetSupport.open(context, "devalay://calendar/day/$date"))
                        setTextViewText(R.id.countdown_emoji, next.optString("emoji", "🪔"))
                        setTextViewText(R.id.countdown_name, next.optString("name"))
                        setViewVisibility(R.id.countdown_days, View.VISIBLE)
                        setTextViewText(R.id.countdown_days, daysText(widgetData, daysBetween(today, date)))
                        val then = upcoming.drop(1).take(2).joinToString("\n") { thenLine(it) }
                        setTextViewText(R.id.countdown_then, then)
                        setViewVisibility(R.id.countdown_then, if (compact || then.isEmpty()) View.GONE else View.VISIBLE)
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

    private fun thenLine(f: JSONObject) = "${f.optString("emoji")} ${f.optString("name")} · ${f.optString("when")}"

    private fun daysText(data: SharedPreferences, days: Long): String = when (days) {
        0L -> WidgetSupport.label(data, "today", "Today")
        1L -> WidgetSupport.label(data, "tomorrow", "Tomorrow")
        else -> WidgetSupport.label(data, "in_days", "In {0} days", days.toString())
    }

    private fun daysBetween(from: String, to: String): Long {
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val a = format.parse(from) ?: return 0
        val b = format.parse(to) ?: return 0
        // Rounded, so a daylight-saving hour does not lose a day.
        return Math.round((b.time - a.time) / TimeUnit.DAYS.toMillis(1).toDouble())
    }
}
