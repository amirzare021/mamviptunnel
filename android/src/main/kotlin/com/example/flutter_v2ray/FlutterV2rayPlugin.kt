package com.example.flutter_v2ray

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/** FlutterV2rayPlugin */
class FlutterV2rayPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private lateinit var v2rayService: V2RayService
  private val tag = "FlutterV2rayPlugin"

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_v2ray")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    v2rayService = V2RayService(context)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "initialize" -> {
        try {
          // Extract V2Ray binary from assets if needed
          extractV2RayBinary()
          result.success(true)
        } catch (e: Exception) {
          Log.e(tag, "Failed to initialize V2Ray: ${e.message}")
          result.error("INIT_ERROR", "Failed to initialize V2Ray", e.message)
        }
      }
      "connect" -> {
        try {
          val config = call.argument<String>("config") ?: throw Exception("Config is null")
          val success = saveConfig(config)
          if (success) {
            result.success(true)
          } else {
            result.error("CONFIG_ERROR", "Failed to save configuration", null)
          }
        } catch (e: Exception) {
          Log.e(tag, "Failed to connect: ${e.message}")
          result.error("CONNECT_ERROR", "Failed to connect to V2Ray server", e.message)
        }
      }
      "start" -> {
        try {
          v2rayService.start()
          result.success(true)
        } catch (e: Exception) {
          Log.e(tag, "Failed to start V2Ray: ${e.message}")
          result.error("START_ERROR", "Failed to start V2Ray service", e.message)
        }
      }
      "stop" -> {
        try {
          v2rayService.stop()
          result.success(true)
        } catch (e: Exception) {
          Log.e(tag, "Failed to stop V2Ray: ${e.message}")
          result.error("STOP_ERROR", "Failed to stop V2Ray service", e.message)
        }
      }
      "isConnected" -> {
        try {
          val isConnected = v2rayService.isRunning()
          result.success(isConnected)
        } catch (e: Exception) {
          Log.e(tag, "Failed to check connection status: ${e.message}")
          result.error("STATUS_ERROR", "Failed to check connection status", e.message)
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    v2rayService.stop()
  }

  private fun extractV2RayBinary() {
    try {
      val assetManager = context.assets
      val v2rayDir = File(context.filesDir, "v2ray")
      
      if (!v2rayDir.exists()) {
        v2rayDir.mkdirs()
      }
      
      val v2rayBinary = File(v2rayDir, "v2ray")
      
      if (!v2rayBinary.exists()) {
        val inputStream = assetManager.open("v2ray/v2ray")
        val outputStream = FileOutputStream(v2rayBinary)
        
        inputStream.use { input ->
          outputStream.use { output ->
            input.copyTo(output)
          }
        }
        
        // Make the binary executable
        val command = "chmod 755 ${v2rayBinary.absolutePath}"
        Runtime.getRuntime().exec(command)
        
        Log.d(tag, "V2Ray binary extracted and made executable")
      }
    } catch (e: IOException) {
      Log.e(tag, "Failed to extract V2Ray binary: ${e.message}")
      throw e
    }
  }

  private fun saveConfig(config: String): Boolean {
    try {
      val configFile = File(context.filesDir, "config.json")
      configFile.writeText(config)
      Log.d(tag, "Config saved to ${configFile.absolutePath}")
      return true
    } catch (e: Exception) {
      Log.e(tag, "Failed to save config: ${e.message}")
      return false
    }
  }
}
