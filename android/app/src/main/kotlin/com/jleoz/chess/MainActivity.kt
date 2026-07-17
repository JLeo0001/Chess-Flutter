package com.jleoz.chess

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERROR", e.message ?: e.toString(), null)
            }
        }
    }
}
