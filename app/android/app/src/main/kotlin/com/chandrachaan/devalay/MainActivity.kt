package com.chandrachaan.devalay

import android.app.WallpaperManager
import android.content.ContentValues
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Hosts Flutter (via AudioServiceActivity for background playback) and exposes
 * the system integrations Flutter cannot do itself: wallpaper, ringtone and gallery.
 */
class MainActivity : AudioServiceActivity() {
    private val io = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(PortabilityPlugin())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "devalay/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                "canWriteSettings" -> result.success(Settings.System.canWrite(this))
                "openWriteSettings" -> {
                    startActivity(Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "setWallpaper" -> background(result) {
                    setWallpaper(call.argument<String>("path")!!, call.argument<Int>("target") ?: 3)
                    null
                }
                "saveImage" -> background(result) {
                    saveImage(call.argument<String>("path")!!, call.argument<String>("name")!!)
                }
                "setRingtone" -> background(result) {
                    setRingtone(call.argument<String>("path")!!, call.argument<String>("title")!!,
                        call.argument<String>("type") ?: "ringtone")
                    null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                runOnUiThread { result.error("FAILED", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    private fun setWallpaper(path: String, target: Int) {
        val manager = WallpaperManager.getInstance(this)
        val bitmap = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException("Unreadable image")
        var flags = 0
        if (target and 1 != 0) flags = flags or WallpaperManager.FLAG_SYSTEM
        if (target and 2 != 0) flags = flags or WallpaperManager.FLAG_LOCK
        manager.setBitmap(bitmap, null, true, flags)
    }

    private fun saveImage(path: String, name: String): String {
        val source = File(path)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, if (name.endsWith(".png")) "image/png" else "image/jpeg")
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Devalay")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create gallery entry")
            contentResolver.openOutputStream(uri)!!.use { out -> source.inputStream().use { it.copyTo(out) } }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return uri.toString()
        }
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Devalay")
        dir.mkdirs()
        val dest = File(dir, name)
        source.copyTo(dest, overwrite = true)
        sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(dest)))
        return dest.absolutePath
    }

    private fun setRingtone(path: String, title: String, type: String) {
        if (!Settings.System.canWrite(this)) throw SecurityException("Modify system settings permission not granted")
        val source = File(path)
        val ringType = when (type) {
            "notification" -> RingtoneManager.TYPE_NOTIFICATION
            "alarm" -> RingtoneManager.TYPE_ALARM
            else -> RingtoneManager.TYPE_RINGTONE
        }
        val folder = when (type) {
            "notification" -> Environment.DIRECTORY_NOTIFICATIONS
            "alarm" -> Environment.DIRECTORY_ALARMS
            else -> Environment.DIRECTORY_RINGTONES
        }
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, "$title.m4a")
            put(MediaStore.Audio.Media.TITLE, title)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mp4")
            put(MediaStore.Audio.Media.IS_RINGTONE, type == "ringtone")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, type == "notification")
            put(MediaStore.Audio.Media.IS_ALARM, type == "alarm")
            put(MediaStore.Audio.Media.IS_MUSIC, false)
        }
        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.Audio.Media.RELATIVE_PATH, folder)
            val target = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val inserted = contentResolver.insert(target, values) ?: throw IllegalStateException("Could not add sound")
            contentResolver.openOutputStream(inserted)!!.use { out -> source.inputStream().use { it.copyTo(out) } }
            inserted
        } else {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(folder).apply { mkdirs() }
            val dest = File(dir, "$title.m4a")
            source.copyTo(dest, overwrite = true)
            @Suppress("DEPRECATION")
            values.put(MediaStore.MediaColumns.DATA, dest.absolutePath)
            contentResolver.insert(MediaStore.Audio.Media.getContentUriForPath(dest.absolutePath)!!, values)
                ?: throw IllegalStateException("Could not add sound")
        }
        RingtoneManager.setActualDefaultRingtoneUri(this, ringType, uri)
    }
}
