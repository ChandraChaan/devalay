package com.chandrachaan.devalay

import android.Manifest
import android.annotation.SuppressLint
import android.app.WallpaperManager
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.content.ContentValues
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.WindowManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.FileProvider
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Hosts Flutter (via AudioServiceActivity for background playback) and exposes
 * the system integrations Flutter cannot do itself: wallpaper, ringtone and gallery.
 */
class MainActivity : AudioServiceActivity() {
    private val io = Executors.newSingleThreadExecutor()

    // Draw behind the status and navigation bars on every Android version, as Android 15 does by default
    // for apps targeting SDK 35+. Flutter's MediaQuery padding keeps content clear of the bars.
    // After super.onCreate: FlutterActivity first swaps LaunchTheme for NormalTheme, and creating the
    // decor view any earlier inflates the launch background in this process.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
    }

    /**
     * Same steps as androidx.core's WindowCompat.enableEdgeToEdge, but every call Android 15 deprecates runs
     * only below Android 15. From Android 15 an app targeting SDK 35+ is always edge-to-edge with
     * transparent bars, so those calls do nothing there, and Play Console flags any unguarded call to them
     * ("Your app uses deprecated APIs or parameters for edge-to-edge"). androidx.core makes the bar-colour
     * calls unguarded, which is why the app does this itself (Flutter's own calls are already guarded).
     * Display-cutout mode uses ALWAYS from Android 11, and the deprecated SHORT_EDGES only on Android 9
     * and 10, where ALWAYS does not exist.
     */
    private fun enableEdgeToEdge() {
        val window = window
        window.decorView
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
            @Suppress("DEPRECATION")
            window.statusBarColor = Color.TRANSPARENT
            @Suppress("DEPRECATION")
            window.navigationBarColor = Color.TRANSPARENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                @Suppress("DEPRECATION")
                window.isStatusBarContrastEnforced = false
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            setCutoutMode(WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            @Suppress("DEPRECATION")
            setCutoutMode(WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES)
        }
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.P)
    private fun setCutoutMode(mode: Int) {
        val attributes = window.attributes
        if (attributes.layoutInDisplayCutoutMode != mode) {
            attributes.layoutInDisplayCutoutMode = mode
            window.attributes = attributes
        }
    }

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
                "shareToWhatsApp" -> result.success(
                    shareToWhatsApp(call.argument<String>("path")!!, call.argument<String>("mime") ?: "image/*",
                        call.argument<String>("text"))
                )
                "approxLocation" -> approxLocation(result)
                "deviceInfo" -> result.success(deviceInfo())
                else -> result.notImplemented()
            }
        }
    }

    // For the owner's usage statistics: which phones Devalay runs on (no identifiers).
    private fun deviceInfo(): Map<String, Any> {
        val memory = android.app.ActivityManager.MemoryInfo()
        (getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager).getMemoryInfo(memory)
        val maker = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
        val model = if (Build.MODEL.startsWith(Build.MANUFACTURER, ignoreCase = true)) Build.MODEL else "$maker ${Build.MODEL}"
        return mapOf("model" to model.take(40), "sdk" to Build.VERSION.SDK_INT, "ramMb" to (memory.totalMem / 1048576L).toInt())
    }

    // "Use my location": coarse, foreground-only, asked for when the user taps it. The position is
    // handed to Flutter to pick the nearest city and is never stored or sent anywhere.
    private var pendingLocation: MethodChannel.Result? = null

    private fun approxLocation(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            readLocation(result)
            return
        }
        pendingLocation?.error("CANCELLED", "Superseded", null)
        pendingLocation = result
        requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), LOCATION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_REQUEST) return
        val result = pendingLocation ?: return
        pendingLocation = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            readLocation(result)
        } else {
            result.error("DENIED", "Location permission denied", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun readLocation(result: MethodChannel.Result) {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
            .filter { runCatching { manager.isProviderEnabled(it) }.getOrDefault(false) }
        if (providers.isEmpty()) {
            result.error("OFF", "Location is turned off", null)
            return
        }
        val answered = AtomicBoolean(false)
        fun answer(location: Location?) {
            if (!answered.compareAndSet(false, true)) return
            if (location == null) {
                result.error("UNAVAILABLE", "No location fix", null)
            } else {
                result.success(mapOf("lat" to location.latitude, "lon" to location.longitude))
            }
        }
        val recent = (providers + LocationManager.PASSIVE_PROVIDER)
            .mapNotNull { runCatching { manager.getLastKnownLocation(it) }.getOrNull() }
            .maxByOrNull { it.time }
        // A fix from the last few minutes is still where the user is; an older one may be the city they
        // travelled from, so ask for a fresh fix and keep the old one only as the fallback.
        if (recent != null && System.currentTimeMillis() - recent.time < 15 * 60 * 1000L) {
            answer(recent)
            return
        }
        val fused = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            runCatching { manager.isProviderEnabled(LocationManager.FUSED_PROVIDER) }.getOrDefault(false)
        val provider = if (fused) LocationManager.FUSED_PROVIDER else providers.first()
        val main = Handler(Looper.getMainLooper())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val cancel = CancellationSignal()
            main.postDelayed({ cancel.cancel(); answer(recent) }, 20_000)
            manager.getCurrentLocation(provider, cancel, mainExecutor) { answer(it ?: recent) }
        } else {
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    manager.removeUpdates(this)
                    answer(location)
                }

                @Deprecated("Deprecated in Java")
                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}
                override fun onProviderEnabled(provider: String) {}
                override fun onProviderDisabled(provider: String) {}
            }
            main.postDelayed({ manager.removeUpdates(listener); answer(recent) }, 20_000)
            manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
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

    // One-tap "Share to WhatsApp": opens WhatsApp (or WhatsApp Business) with the file, where "My status" is the
    // first choice. False when neither is installed, so the app falls back to the system share sheet.
    private fun shareToWhatsApp(path: String, mime: String, text: String?): Boolean {
        val uri = FileProvider.getUriForFile(this, "$packageName.devalay.files", File(path))
        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                setPackage(pkg)
                putExtra(Intent.EXTRA_STREAM, uri)
                if (!text.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, text)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
            }
        }
        return false
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

    private companion object {
        const val LOCATION_REQUEST = 4107
    }
}
