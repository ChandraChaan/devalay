package com.chandrachaan.devalay

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * The running Choghadiya, or Rahu Kalam while it is on. The app writes each day's periods as epoch
 * times with the labels already in the user's language. The widget redraws itself at the next
 * boundary with an inexact, non-waking alarm: no exact-alarm permission, no wake-ups while the
 * phone sleeps, and the text is right whenever the screen is on.
 */
class NowWidget : HomeWidgetProvider() {
    private data class Period(val start: Long, val end: Long, val name: String, val quality: String, val until: String)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val days = WidgetSupport.json(widgetData, "now_days")
        val today = days.optJSONObject(WidgetSupport.dateKey())
        // Night Choghadiyas run to the next sunrise, so before dawn the current one is yesterday's.
        val periods = listOfNotNull(days.optJSONObject(WidgetSupport.yesterdayKey()), today)
            .flatMap { parse(it.optJSONArray("periods")) }
        val current = periods.firstOrNull { now >= it.start && now < it.end }
        val rahu = today?.optJSONArray("rahu")
        val rahuStart = rahu?.optLong(0) ?: 0L
        val rahuEnd = rahu?.optLong(1) ?: 0L
        val rahuText = rahu?.optString(2).orEmpty()
        val inRahu = rahu != null && now >= rahuStart && now < rahuEnd
        fun label(key: String, fallback: String, arg: String = "") = WidgetSupport.label(widgetData, key, fallback, arg)

        for (id in appWidgetIds) {
            val views = WidgetSupport.responsive(context, appWidgetManager, id, 100) { compact ->
                RemoteViews(context.packageName, R.layout.now_widget).apply {
                    setOnClickPendingIntent(R.id.now_root, WidgetSupport.open(context, "devalay://panchang"))
                    setViewVisibility(R.id.now_title, if (compact) View.GONE else View.VISIBLE)
                    when {
                        inRahu -> {
                            setTextViewText(R.id.now_title, label("rahu", "Rahu Kalam"))
                            setTextViewText(R.id.now_status, "⚠️ ${label("rahu_now", "Rahu Kalam now")}")
                            setTextColor(R.id.now_status, color("bad"))
                            setTextViewText(R.id.now_until, rahuText)
                            setViewVisibility(R.id.now_until, View.VISIBLE)
                            setViewVisibility(R.id.now_rahu, View.GONE)
                        }
                        current != null -> {
                            setTextViewText(R.id.now_title, label("choghadiya", "Choghadiya now"))
                            setTextViewText(R.id.now_status, "${current.name} · ${label(current.quality, current.quality)}")
                            setTextColor(R.id.now_status, color(current.quality))
                            setTextViewText(R.id.now_until, label("until", "until {0}", current.until))
                            setViewVisibility(R.id.now_until, View.VISIBLE)
                            val line = when {
                                rahu == null -> ""
                                now < rahuStart -> "${label("rahu", "Rahu Kalam")}: $rahuText"
                                else -> label("rahu_over", "")
                            }
                            setTextViewText(R.id.now_rahu, line)
                            setViewVisibility(R.id.now_rahu, if (compact || line.isEmpty()) View.GONE else View.VISIBLE)
                        }
                        else -> {
                            setTextViewText(R.id.now_title, label("choghadiya", "Choghadiya now"))
                            setTextViewText(R.id.now_status, label("empty", "Open Devalay"))
                            setTextColor(R.id.now_status, Color.WHITE)
                            setInt(R.id.now_status, "setMaxLines", 2)
                            setViewVisibility(R.id.now_until, View.GONE)
                            setViewVisibility(R.id.now_rahu, View.GONE)
                        }
                    }
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }

        val next = (periods.map { it.end } + listOf(rahuStart, rahuEnd)).filter { it > now }.minOrNull()
        schedule(context, next)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        super.onAppWidgetOptionsChanged(context, manager, id, options)
        onUpdate(context, manager, intArrayOf(id))
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        schedule(context, null)
    }

    private fun parse(list: JSONArray?): List<Period> {
        if (list == null) return emptyList()
        return (0 until list.length()).mapNotNull { i ->
            val p = list.optJSONArray(i) ?: return@mapNotNull null
            Period(p.optLong(0), p.optLong(1), p.optString(2), p.optString(3), p.optString(4))
        }
    }

    private fun color(quality: String): Int = when (quality) {
        "best" -> Color.parseColor("#FFA5F2B5")
        "good" -> Color.parseColor("#FFD6F5A3")
        "bad" -> Color.parseColor("#FFFFB4A8")
        else -> Color.WHITE
    }

    /** Redraws all "now" widgets at [at] (a few seconds after the boundary), or cancels the alarm. */
    private fun schedule(context: Context, at: Long?) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, NowWidget::class.java))
        val intent = Intent(context, NowWidget::class.java)
            .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        val pending = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (at == null || ids.isEmpty()) {
            alarms.cancel(pending)
            return
        }
        // RTC (not RTC_WAKEUP) never wakes a sleeping phone; the one-minute window lets Android batch it.
        alarms.setWindow(AlarmManager.RTC, at + 5_000, 60_000, pending)
    }

    private companion object {
        const val REQUEST_CODE = 7301
    }
}
