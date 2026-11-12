package com.deividi.protocolos

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction

// Recebe prints e arquivos CSV compartilhados de outros apps, e abre o seletor de arquivos
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val pendingImages = mutableListOf<String>()
    private val pendingCsv = mutableListOf<String>()
    private var pickResult: MethodChannel.Result? = null

    companion object {
        private const val PICK_CSV = 4242
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "protocolos/share")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getShared" -> {
                    result.success(ArrayList(pendingImages))
                    pendingImages.clear()
                }
                "getSharedCsv" -> {
                    result.success(ArrayList(pendingCsv))
                    pendingCsv.clear()
                }
                "pickCsv" -> pickCsv(result)
                else -> result.notImplemented()
            }
        }
        handleIntent(intent, false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent, true)
    }

    // ---------- seletor de arquivo ----------
    @Suppress("DEPRECATION")
    private fun pickCsv(result: MethodChannel.Result) {
        pickResult?.success(null)
        pickResult = result
        val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        try {
            startActivityForResult(i, PICK_CSV)
        } catch (e: Exception) {
            pickResult = null
            result.error("sem_seletor", e.message, null)
        }
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_CSV) return
        val r = pickResult ?: return
        pickResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            r.success(null)
            return
        }
        r.success(readText(uri))
    }

    // ---------- compartilhar ----------
    private fun handleIntent(intent: Intent?, notify: Boolean) {
        if (intent == null) return
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> getUri(intent)?.let { uris.add(it) }
            Intent.ACTION_SEND_MULTIPLE -> getUris(intent)?.let { uris.addAll(it) }
            else -> return
        }
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        val intentType = intent.type ?: ""
        intent.action = null // não processar de novo ao girar a tela
        var got = false
        for (u in uris) {
            val mime = (contentResolver.getType(u) ?: intentType).lowercase()
            if (mime.startsWith("image/")) {
                copyToCache(u)?.let { pendingImages.add(it); got = true }
            } else {
                readText(u)?.let { pendingCsv.add(it); got = true }
            }
        }
        if (uris.isEmpty() && !sharedText.isNullOrBlank()) {
            pendingCsv.add(sharedText)
            got = true
        }
        if (got && notify) channel?.invokeMethod("shared", null)
    }

    @Suppress("DEPRECATION")
    private fun getUri(i: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun getUris(i: Intent): List<Uri>? =
        if (Build.VERSION.SDK_INT >= 33) i.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else i.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)

    private fun copyToCache(uri: Uri): String? {
        return try {
            val f = File(cacheDir, "compartilhado_${System.currentTimeMillis()}_${(0..99999).random()}.jpg")
            contentResolver.openInputStream(uri)?.use { input ->
                f.outputStream().use { output -> input.copyTo(output) }
            }
            if (f.exists() && f.length() > 0) f.absolutePath else null
        } catch (e: Exception) {
            null
        }
    }

    private fun readText(uri: Uri): String? {
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
            decode(bytes)
        } catch (e: Exception) {
            null
        }
    }

    // UTF-8; se não for, usa Latin-1 (arquivos antigos do Excel)
    private fun decode(bytes: ByteArray): String {
        return try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes))
                .toString()
        } catch (e: CharacterCodingException) {
            String(bytes, Charsets.ISO_8859_1)
        }
    }
}
