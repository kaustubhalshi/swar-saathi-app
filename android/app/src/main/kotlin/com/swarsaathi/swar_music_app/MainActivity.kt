package com.swarsaathi.swar_music_app

import android.content.Context
import android.media.AudioManager
import android.media.AudioDeviceInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "audio_route"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentInputDevice" -> {
                    result.success(getCurrentInputDevice())
                }
                "getCurrentOutputDevice" -> {
                    result.success(getCurrentOutputDevice())
                }
                "isHeadsetMicConnected" -> {
                    result.success(isHeadsetMicConnected())
                }
                "isHeadsetConnected" -> {
                    result.success(isHeadsetConnected())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getCurrentInputDevice(): String {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)

            for (device in devices) {
                when (device.type) {
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> return "headset"
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> return "headset"
                    AudioDeviceInfo.TYPE_USB_HEADSET -> return "headset"
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> return "bluetooth"
                    AudioDeviceInfo.TYPE_BUILTIN_MIC -> return "builtin"
                }
            }
            "builtin"
        } catch (e: Exception) {
            "builtin"
        }
    }

    private fun getCurrentOutputDevice(): String {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

            for (device in devices) {
                when (device.type) {
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> return "headphones"
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> return "headphones"
                    AudioDeviceInfo.TYPE_USB_HEADSET -> return "headphones"
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> return "bluetooth"
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> return "speaker"
                }
            }
            "speaker"
        } catch (e: Exception) {
            "speaker"
        }
    }

    private fun isHeadsetMicConnected(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)

            for (device in devices) {
                when (device.type) {
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_USB_HEADSET -> return true
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun isHeadsetConnected(): Boolean {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

            for (device in devices) {
                when (device.type) {
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_USB_HEADSET,
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> return true
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }
}