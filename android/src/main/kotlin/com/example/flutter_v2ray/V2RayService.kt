package com.example.flutter_v2ray

import android.content.Context
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.lang.Exception

/**
 * Service class to manage V2Ray process
 */
class V2RayService(private val context: Context) {
    private var process: Process? = null
    private val tag = "V2RayService"

    /**
     * Start the V2Ray service with the current configuration
     */
    fun start() {
        if (isRunning()) {
            Log.d(tag, "V2Ray is already running")
            return
        }

        try {
            // Verify binary exists
            val v2rayBinary = File(context.filesDir, "v2ray/v2ray")
            if (!v2rayBinary.exists()) {
                throw Exception("V2Ray binary not found at ${v2rayBinary.absolutePath}")
            }

            // Verify config exists
            val configFile = File(context.filesDir, "config.json")
            if (!configFile.exists()) {
                throw Exception("Config file not found at ${configFile.absolutePath}")
            }

            // Start V2Ray process
            val command = arrayOf(
                v2rayBinary.absolutePath,
                "-config",
                configFile.absolutePath
            )

            Log.d(tag, "Starting V2Ray process: ${command.joinToString(" ")}")
            process = Runtime.getRuntime().exec(command)

            // Create a thread to read process output
            Thread {
                val reader = BufferedReader(InputStreamReader(process?.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    Log.d(tag, "V2Ray: $line")
                }
            }.start()

            // Create a thread to read process error output
            Thread {
                val reader = BufferedReader(InputStreamReader(process?.errorStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    Log.e(tag, "V2Ray Error: $line")
                }
            }.start()

            Log.d(tag, "V2Ray process started successfully")
        } catch (e: Exception) {
            Log.e(tag, "Failed to start V2Ray: ${e.message}", e)
            throw e
        }
    }

    /**
     * Stop the V2Ray service
     */
    fun stop() {
        try {
            process?.let {
                Log.d(tag, "Stopping V2Ray process")
                it.destroy()
                // Wait for process to exit
                if (it.waitFor() == 0) {
                    Log.d(tag, "V2Ray process stopped successfully")
                } else {
                    Log.w(tag, "V2Ray process exited with non-zero code")
                }
                process = null
            }
        } catch (e: Exception) {
            Log.e(tag, "Failed to stop V2Ray: ${e.message}", e)
            process = null
            throw e
        }
    }

    /**
     * Check if V2Ray service is running
     */
    fun isRunning(): Boolean {
        return try {
            val p = process
            if (p == null) {
                false
            } else {
                // Check if process is still alive
                try {
                    p.exitValue()
                    false // If we got here, process has exited
                } catch (e: IllegalThreadStateException) {
                    true // Process is still running
                }
            }
        } catch (e: Exception) {
            Log.e(tag, "Error checking if V2Ray is running: ${e.message}")
            false
        }
    }
}
