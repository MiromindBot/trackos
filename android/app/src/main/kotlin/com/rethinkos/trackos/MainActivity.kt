package com.rethinkos.trackos

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val LOCATION_CHANNEL = "com.rethinkos.trackos/location"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createForegroundNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isLocationServiceEnabled" -> {
                    result.success(isNativeLocationServiceEnabled())
                }
                "openLocationSettings" -> {
                    try {
                        val intent = android.content.Intent(
                            android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS
                        )
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Check if system location service is enabled using native Android LocationManager.
     *
     * This bypasses Google Play Services' FusedLocationProviderClient which
     * requires Google Location Accuracy to be enabled. On devices without
     * Google Play Services (e.g., Chinese market phones), or when Google
     * Location Accuracy is disabled, the native LocationManager check
     * correctly reflects the system GPS/network location status.
     *
     * Checks both GPS_PROVIDER and NETWORK_PROVIDER, returning true if
     * either is enabled.
     */
    private fun isNativeLocationServiceEnabled(): Boolean {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return false

        return try {
            val gpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val networkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            gpsEnabled || networkEnabled
        } catch (e: Exception) {
            false
        }
    }

    private fun createForegroundNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "trackos_location",
                "TrackOS Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "前台定位追踪服务通知"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
