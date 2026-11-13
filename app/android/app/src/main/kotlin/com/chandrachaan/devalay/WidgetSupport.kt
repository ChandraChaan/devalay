package com.chandrachaan.devalay

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Helpers shared by the home-screen widgets. The app writes every text already in the user's language. */
object WidgetSupport {
    fun dateKey(date: Date = Date()): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(date)

    fun yesterdayKey(): String = dateKey(Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }.time)

    fun json(data: SharedPreferences, key: String): JSONObject = try {
        JSONObject(data.getString(key, null) ?: "{}")
    } catch (e: Exception) {
        JSONObject()
    }

    /** A word from the app's labels ("Next festival", "until {0}"), with [arg] in place of {0}. */
    fun label(data: SharedPreferences, key: String, fallback: String, arg: String = ""): String =
        json(data, "widget_labels").optString(key, fallback).replace("{0}", arg)

    /** Opens the app on a devalay:// link through the home_widget launch intent (see features/shell.dart). */
    fun open(context: Context, link: String) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(link))

    /**
     * Gives the launcher a compact and a full layout. Android 12+ picks between them itself as the
     * widget is resized; older versions get the one that fits the size the launcher reports.
     */
    fun responsive(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        compactBelowHeightDp: Int,
        build: (compact: Boolean) -> RemoteViews,
    ): RemoteViews {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return RemoteViews(
                mapOf(
                    SizeF(100f, 40f) to build(true),
                    SizeF(100f, compactBelowHeightDp.toFloat()) to build(false),
                ),
            )
        }
        val height = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return build(height in 1 until compactBelowHeightDp)
    }
}
