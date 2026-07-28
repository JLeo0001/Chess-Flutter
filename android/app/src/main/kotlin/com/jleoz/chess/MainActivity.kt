package com.jleoz.chess

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.jleoz.chess/stockfish"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getCpuArch" -> {
                        val abis = Build.SUPPORTED_ABIS
                        result.success(if (abis.isNotEmpty()) abis[0] else Build.CPU_ABI)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path") ?: run {
                            result.error("NO_PATH", "File path is null", null)
                            return@setMethodCallHandler
                        }
                        installApk(path)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERROR", e.message ?: e.toString(), null)
            }
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) throw Exception("File not found: $path")

        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
        } else {
            Uri.fromFile(file)
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        startActivity(intent)
    }
}
