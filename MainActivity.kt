package com.deividi.protocolos

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Recebe prints compartilhados de outros apps (Compartilhar → Meus Protocolos)
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val pending = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "protocolos/share")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getShared") {
                result.success(ArrayList(pending))
                pending.clear()
            } else {
                result.notImplemented()
            }
        }
        handleIntent(intent, false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, true)
    }

    private fun handleIntent(intent: Intent?, notify: Boolean) {
        if (intent == null) return
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> getUri(intent)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE -> getUris(intent)?.let { uris.addAll(it) }
            else -> return
        }
        intent.action = null // não processar de novo ao girar a tela
        val paths = uris.mapNotNull { copyToCache(it) }
        if (paths.isEmpty()) return
        pending.addAll(paths)
        if (notify) channel?.invokeMethod("shared", null)
    }

    @Suppress("DEPRECATION")
    private fun getUri(i: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun getUris(i: Intent): List<Uri>? =
        if (Build.VERSION.SDK_INT >= 33) i.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else i.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)

    private fun copyToCache(uri: Uri): String? = try {
        val f = File(cacheDir, "compartilhado_${System.currentTimeMillis()}_${(0..99999).random()}.jpg")
        contentResolver.openInputStream(uri)?.use { input ->
            f.outputStream().use { output -> input.copyTo(output) }
        }
        if (f.exists() && f.length() > 0) f.absolutePath else null
    } catch (e: Exception) {
        null
    }
}
