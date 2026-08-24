package com.example.playon

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.MediaScannerConnection
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {

    private val CHANNEL_SCANNER = "com.playon.media_scanner"
    private val CHANNEL_YTDLP = "com.playon.ytdlp"
    private val CHANNEL_EQUALIZER = "com.playon.equalizer"
    private val CHANNEL_TAGS = "com.playon.tags"
    private val CHANNEL_NOTIF = "com.playon.download_notification"

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var currentAudioSessionId: Int = 0
    private val DOWNLOAD_NOTIF_CHANNEL_ID = "playon_downloads"
    private val DOWNLOAD_NOTIF_ID = 9001
    
    // Pool de hilos reutilizables para operaciones I/O en segundo plano (ahorro de RAM y CPU)
    private val backgroundExecutor = Executors.newFixedThreadPool(3)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        // Configurar la ruta privada de caché de la app para yt-dlp y archivos temporales
        try {
            val py = Python.getInstance()
            val module = py.getModule("ytdlp_helper")
            module.callAttr("set_temp_dir", cacheDir.absolutePath)
        } catch (_: Exception) {}

        createNotificationChannel()

        // ── 1. Media Scanner Channel ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SCANNER)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGUMENT", "path must not be null", null)
                            return@setMethodCallHandler
                        }
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(path),
                            null
                        ) { scannedPath, uri ->
                            runOnUiThread {
                                if (uri != null) {
                                    result.success(uri.toString())
                                } else {
                                    result.success(null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 2. yt-dlp Channel ────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_YTDLP)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAudioUrl" -> {
                        val url = call.argument<String>("url")
                        val cookies = call.argument<String>("cookies") ?: ""
                        if (url == null) {
                            result.error("INVALID_ARGUMENT", "url must not be null", null)
                            return@setMethodCallHandler
                        }
                        backgroundExecutor.execute {
                            try {
                                val py = Python.getInstance()
                                val module = py.getModule("ytdlp_helper")
                                val audioUrl = module.callAttr("get_audio_url", url, cookies).toString()
                                
                                runOnUiThread {
                                    if (audioUrl.startsWith("ERROR:")) {
                                        result.error("YTDLP_ERROR", audioUrl, null)
                                    } else {
                                        result.success(audioUrl)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("YTDLP_EXCEPTION", e.message, null)
                                }
                            }
                        }
                    }
                    "getPlaylistInfo" -> {
                        val url = call.argument<String>("url")
                        val cookies = call.argument<String>("cookies") ?: ""
                        if (url == null) {
                            result.error("INVALID_ARGUMENT", "url must not be null", null)
                            return@setMethodCallHandler
                        }
                        backgroundExecutor.execute {
                            try {
                                val py = Python.getInstance()
                                val module = py.getModule("ytdlp_helper")
                                val jsonString = module.callAttr("get_playlist_info", url, cookies).toString()
                                
                                runOnUiThread {
                                    result.success(jsonString)
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("YTDLP_EXCEPTION", e.message, null)
                                }
                            }
                        }
                    }
                    "downloadAudio" -> {
                        val url = call.argument<String>("url")
                        val outPath = call.argument<String>("outPath")
                        val title = call.argument<String>("title") ?: ""
                        val artist = call.argument<String>("artist") ?: ""
                        val album = call.argument<String>("album") ?: ""
                        val thumbnailUrl = call.argument<String>("thumbnailUrl") ?: ""
                        val cookies = call.argument<String>("cookies") ?: ""
                        if (url == null || outPath == null) {
                            result.error("INVALID_ARGUMENT", "url and outPath must not be null", null)
                            return@setMethodCallHandler
                        }
                        backgroundExecutor.execute {
                            try {
                                val py = Python.getInstance()
                                val module = py.getModule("ytdlp_helper")
                                val downloadResult = module.callAttr(
                                    "download_audio",
                                    url,
                                    outPath,
                                    title,
                                    artist,
                                    album,
                                    thumbnailUrl,
                                    cookies
                                ).toString()
                                
                                runOnUiThread {
                                    if (downloadResult.startsWith("ERROR:")) {
                                        result.error("YTDLP_ERROR", downloadResult, null)
                                    } else {
                                        result.success(downloadResult)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("YTDLP_EXCEPTION", e.message, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 3. Audio Effect Equalizer Channel ─────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_EQUALIZER)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initEqualizer" -> {
                        try {
                            val sessionId = call.argument<Int>("audioSessionId") ?: 0

                            if (currentAudioSessionId != 0 && currentAudioSessionId != sessionId) {
                                try {
                                    val closeIntent = android.content.Intent(android.media.audiofx.AudioEffect.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION).apply {
                                        putExtra(android.media.audiofx.AudioEffect.EXTRA_AUDIO_SESSION, currentAudioSessionId)
                                        putExtra(android.media.audiofx.AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                                    }
                                    sendBroadcast(closeIntent)
                                } catch (_: Exception) {}
                            }

                            try {
                                equalizer?.release()
                                bassBoost?.release()
                            } catch (_: Exception) {}

                            currentAudioSessionId = sessionId

                            if (sessionId != 0) {
                                try {
                                    val openIntent = android.content.Intent(android.media.audiofx.AudioEffect.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION).apply {
                                        putExtra(android.media.audiofx.AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                                        putExtra(android.media.audiofx.AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                                        putExtra(android.media.audiofx.AudioEffect.EXTRA_CONTENT_TYPE, android.media.audiofx.AudioEffect.CONTENT_TYPE_MUSIC)
                                    }
                                    sendBroadcast(openIntent)
                                } catch (_: Exception) {}
                            }

                            try {
                                equalizer = Equalizer(1000, sessionId)
                            } catch (_: Exception) {
                                try {
                                    equalizer = Equalizer(0, sessionId)
                                } catch (_: Exception) {
                                    equalizer = null
                                }
                            }

                            try {
                                bassBoost = BassBoost(1000, sessionId)
                            } catch (_: Exception) {
                                try {
                                    bassBoost = BassBoost(0, sessionId)
                                } catch (_: Exception) {
                                    bassBoost = null
                                }
                            }

                            val numBands = equalizer?.numberOfBands?.toInt() ?: 5
                            val minLevel = equalizer?.bandLevelRange?.get(0)?.toInt() ?: -1500
                            val maxLevel = equalizer?.bandLevelRange?.get(1)?.toInt() ?: 1500

                            val centerFreqs = mutableListOf<Int>()
                            if (equalizer != null && numBands > 0) {
                                for (i in 0 until numBands) {
                                    centerFreqs.add(equalizer?.getCenterFreq(i.toShort()) ?: 0)
                                }
                            } else {
                                centerFreqs.addAll(listOf(60000, 230000, 910000, 3600000, 14000000))
                            }

                            val numPresets = equalizer?.numberOfPresets?.toInt() ?: 0
                            val presets = mutableListOf<String>()
                            for (i in 0 until numPresets) {
                                presets.add(equalizer?.getPresetName(i.toShort()) ?: "Preset $i")
                            }

                            val bandLevels = mutableListOf<Int>()
                            if (equalizer != null && numBands > 0) {
                                for (i in 0 until numBands) {
                                    bandLevels.add(equalizer?.getBandLevel(i.toShort())?.toInt() ?: 0)
                                }
                            }

                            val response = mapOf(
                                "numBands" to numBands,
                                "minLevel" to minLevel,
                                "maxLevel" to maxLevel,
                                "centerFreqs" to centerFreqs,
                                "presets" to presets,
                                "bandLevels" to bandLevels,
                                "enabled" to (equalizer?.enabled ?: false),
                                "bassBoost" to (bassBoost?.roundedStrength?.toInt() ?: 0)
                            )
                            result.success(response)
                        } catch (e: Exception) {
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            equalizer?.enabled = enabled
                            bassBoost?.enabled = enabled
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setBandLevel" -> {
                        val band = call.argument<Int>("band")?.toShort() ?: 0
                        val level = call.argument<Int>("level")?.toShort() ?: 0
                        try {
                            equalizer?.setBandLevel(band, level)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "usePreset" -> {
                        val preset = call.argument<Int>("preset")?.toShort() ?: 0
                        try {
                            equalizer?.usePreset(preset)
                            val numBands = equalizer?.numberOfBands?.toInt() ?: 0
                            val bandLevels = mutableListOf<Int>()
                            for (i in 0 until numBands) {
                                bandLevels.add(equalizer?.getBandLevel(i.toShort())?.toInt() ?: 0)
                            }
                            result.success(bandLevels)
                        } catch (e: Exception) {
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "getBandLevels" -> {
                        try {
                            val numBands = equalizer?.numberOfBands?.toInt() ?: 0
                            val bandLevels = mutableListOf<Int>()
                            for (i in 0 until numBands) {
                                bandLevels.add(equalizer?.getBandLevel(i.toShort())?.toInt() ?: 0)
                            }
                            result.success(bandLevels)
                        } catch (e: Exception) {
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    "setBassBoost" -> {
                        val strength = call.argument<Int>("strength")?.toShort() ?: 0
                        try {
                            if (bassBoost?.strengthSupported == true) {
                                bassBoost?.setStrength(strength)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("EQ_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 4. Audio Tags ID3 Channel ─────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_TAGS)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAudioTags" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGUMENT", "path must not be null", null)
                            return@setMethodCallHandler
                        }
                        backgroundExecutor.execute {
                            try {
                                val py = Python.getInstance()
                                val module = py.getModule("ytdlp_helper")
                                val jsonString = module.callAttr("get_audio_tags", path).toString()
                                runOnUiThread { result.success(jsonString) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("TAG_ERROR", e.message, null) }
                            }
                        }
                    }
                    "setAudioTags" -> {
                        val path = call.argument<String>("path")
                        val title = call.argument<String>("title") ?: ""
                        val artist = call.argument<String>("artist") ?: ""
                        val album = call.argument<String>("album") ?: ""
                        if (path == null) {
                            result.error("INVALID_ARGUMENT", "path must not be null", null)
                            return@setMethodCallHandler
                        }
                        backgroundExecutor.execute {
                            try {
                                val py = Python.getInstance()
                                val module = py.getModule("ytdlp_helper")
                                val res = module.callAttr("set_audio_tags", path, title, artist, album).toString()
                                
                                // Re-escaneo multimedia
                                MediaScannerConnection.scanFile(applicationContext, arrayOf(path), null, null)
                                
                                runOnUiThread {
                                    if (res == "SUCCESS") {
                                        result.success(true)
                                    } else {
                                        result.error("TAG_ERROR", res, null)
                                    }
                                }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("TAG_ERROR", e.message, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ── 5. Download Notifications Channel ─────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NOTIF)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateProgress" -> {
                        val title = call.argument<String>("title") ?: "Descargando audio"
                        val text = call.argument<String>("text") ?: ""
                        val progress = call.argument<Int>("progress") ?: 0
                        val max = call.argument<Int>("max") ?: 100

                        val notification = NotificationCompat.Builder(this, DOWNLOAD_NOTIF_CHANNEL_ID)
                            .setContentTitle(title)
                            .setContentText(text)
                            .setSmallIcon(R.mipmap.launcher_icon)
                            .setProgress(max, progress, false)
                            .setOngoing(true)
                            .setOnlyAlertOnce(true)
                            .build()

                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.notify(DOWNLOAD_NOTIF_ID, notification)
                        result.success(true)
                    }
                    "finishProgress" -> {
                        val title = call.argument<String>("title") ?: "Descarga completada"
                        val text = call.argument<String>("text") ?: "Canciones guardadas en tu biblioteca"

                        val notification = NotificationCompat.Builder(this, DOWNLOAD_NOTIF_CHANNEL_ID)
                            .setContentTitle(title)
                            .setContentText(text)
                            .setSmallIcon(R.drawable.ic_notification)
                            .setProgress(0, 0, false)
                            .setOngoing(false)
                            .setAutoCancel(true)
                            .build()

                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.notify(DOWNLOAD_NOTIF_ID, notification)
                        result.success(true)
                    }
                    "cancelNotification" -> {
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.cancel(DOWNLOAD_NOTIF_ID)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                DOWNLOAD_NOTIF_CHANNEL_ID,
                "Descargas PlayOn",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Progreso de descargas de música"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        if (currentAudioSessionId != 0) {
            try {
                val closeIntent = android.content.Intent(android.media.audiofx.AudioEffect.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION).apply {
                    putExtra(android.media.audiofx.AudioEffect.EXTRA_AUDIO_SESSION, currentAudioSessionId)
                    putExtra(android.media.audiofx.AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                }
                sendBroadcast(closeIntent)
            } catch (_: Exception) {}
        }
        try {
            backgroundExecutor.shutdownNow()
            equalizer?.release()
            bassBoost?.release()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}

