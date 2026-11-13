package com.chandrachaan.devalay

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.ContactsContract
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/**
 * Backup files, calendar entries and contact birthdays, all on the phone (channel "devalay/portability"):
 * - saveFile / openFile: the system file picker (Storage Access Framework), so no storage permission;
 * - addToCalendar: hands one event to the user's calendar app, which asks before saving it;
 * - contactsPermission / requestContacts / contactEvents: READ_CONTACTS, asked only after the in-app
 *   disclosure, and only the birthday and anniversary rows (name, date, type) are read.
 */
class PortabilityPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener {

    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private val io = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var pendingText: String? = null

    private val activity: Activity? get() = binding?.activity

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(b.binaryMessenger, "devalay/portability").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        binding = b
        b.addActivityResultListener(this)
        b.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
    }

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val activity = activity ?: return result.error("NO_ACTIVITY", "No activity", null)
        when (call.method) {
            "saveFile" -> start(result, call.argument<String>("text")) {
                Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                    .setType(call.argument<String>("mime") ?: "application/json")
                    .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
            }
            "openFile" -> start(result, null) {
                // Some file managers label .json as octet-stream, so accept anything and check the content.
                Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
                    .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
            }
            "addToCalendar" -> {
                val begin = call.argument<Number>("begin")!!.toLong()
                val intent = Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
                    .putExtra(CalendarContract.Events.TITLE, call.argument<String>("title"))
                    .putExtra(CalendarContract.Events.DESCRIPTION, call.argument<String>("description") ?: "")
                    .putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, true)
                    .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, begin)
                    .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, begin + 24L * 60 * 60 * 1000)
                call.argument<String>("rrule")?.let { intent.putExtra(CalendarContract.Events.RRULE, it) }
                try {
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }
            "contactsPermission" -> result.success(hasContacts())
            "requestContacts" -> {
                if (hasContacts()) return result.success(true)
                if (pending != null) return result.error("BUSY", "Another request is open", null)
                pending = result
                activity.requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), PERMISSION_CODE)
            }
            "contactEvents" -> {
                if (!hasContacts()) return result.error("DENIED", "Contacts permission not granted", null)
                io.execute {
                    try {
                        val rows = contactEvents()
                        activity.runOnUiThread { result.success(rows) }
                    } catch (e: Exception) {
                        activity.runOnUiThread { result.error("FAILED", e.message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun hasContacts(): Boolean {
        val a = activity ?: return false
        return a.checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
    }

    private fun start(result: MethodChannel.Result, text: String?, intent: () -> Intent) {
        if (pending != null) return result.error("BUSY", "Another request is open", null)
        pending = result
        pendingText = text
        try {
            activity!!.startActivityForResult(intent(), if (text != null) SAVE_CODE else OPEN_CODE)
        } catch (e: ActivityNotFoundException) {
            finish(null)
        }
    }

    private fun finish(value: Any?) {
        val r = pending
        pending = null
        pendingText = null
        r?.success(value)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SAVE_CODE && requestCode != OPEN_CODE) return false
        val uri: Uri? = if (resultCode == Activity.RESULT_OK) data?.data else null
        val activity = activity
        if (uri == null || activity == null) {
            finish(null)
            return true
        }
        val result = pending
        val text = pendingText
        pending = null
        pendingText = null
        io.execute {
            try {
                val value: Any? = if (requestCode == SAVE_CODE) {
                    activity.contentResolver.openOutputStream(uri, "wt")!!.use { it.write(text!!.toByteArray()) }
                    true
                } else {
                    activity.contentResolver.openInputStream(uri)!!.use { input ->
                        val bytes = input.readBytes()
                        if (bytes.size > MAX_FILE) throw IllegalArgumentException("File too large")
                        String(bytes)
                    }
                }
                activity.runOnUiThread { result?.success(value) }
            } catch (e: Exception) {
                activity.runOnUiThread { result?.error("FAILED", e.message ?: e.javaClass.simpleName, null) }
            }
        }
        return true
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_CODE) return false
        val r = pending
        pending = null
        r?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
        return true
    }

    /** Birthday and anniversary rows only: display name, date as stored, type, and the contact's lookup key. */
    private fun contactEvents(): List<Map<String, Any?>> {
        val projection = arrayOf(
            ContactsContract.Data.LOOKUP_KEY,
            ContactsContract.Data.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Event.START_DATE,
            ContactsContract.CommonDataKinds.Event.TYPE,
        )
        val selection = "${ContactsContract.Data.MIMETYPE} = ? AND ${ContactsContract.CommonDataKinds.Event.TYPE} IN (?, ?)"
        val args = arrayOf(
            ContactsContract.CommonDataKinds.Event.CONTENT_ITEM_TYPE,
            ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY.toString(),
            ContactsContract.CommonDataKinds.Event.TYPE_ANNIVERSARY.toString(),
        )
        val out = mutableListOf<Map<String, Any?>>()
        activity!!.contentResolver.query(ContactsContract.Data.CONTENT_URI, projection, selection, args, null)?.use { c ->
            while (c.moveToNext()) {
                val type = c.getInt(3)
                out.add(
                    mapOf(
                        "key" to c.getString(0),
                        "name" to c.getString(1),
                        "date" to c.getString(2),
                        "kind" to if (type == ContactsContract.CommonDataKinds.Event.TYPE_BIRTHDAY) "birthday" else "anniversary",
                    ),
                )
            }
        }
        return out
    }

    private companion object {
        const val SAVE_CODE = 7311
        const val OPEN_CODE = 7312
        const val PERMISSION_CODE = 7313
        const val MAX_FILE = 5 * 1024 * 1024
    }
}
