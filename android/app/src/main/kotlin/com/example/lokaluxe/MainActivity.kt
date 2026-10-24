package com.example.lokaluxe

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val notificationChannel = "com.example.lokaluxe/game_notifications"
    private val notificationId = 20261021
    private var pendingVoucherNotification: Pair<String, String>? = null
    private var pendingProfilePhotoResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createVoucherNotificationChannel()
        TripReminderReceiver.cancelLegacyDailyEngagement(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannel,
        ).setMethodCallHandler { call, result ->
            if (call.method != "showVoucherNotification") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val title = call.argument<String>("title")
            val body = call.argument<String>("body")
            if (title.isNullOrBlank() || body.isNullOrBlank()) {
                result.error("invalid_notification", "Judul dan isi notifikasi wajib diisi.", null)
                return@setMethodCallHandler
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                pendingVoucherNotification = title to body
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_NOTIFICATION_PERMISSION,
                )
                result.success("permission_requested")
                return@setMethodCallHandler
            }

            showVoucherNotification(title, body)
            result.success("shown")
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TRIP_REMINDER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleTripReminders" -> {
                    val tripId = call.argument<Int>("tripId")
                    val destination = call.argument<String>("destination")
                    val startDateMillis =
                        call.argument<Number>("startDateMillis")?.toLong()
                    if (tripId == null ||
                        destination.isNullOrBlank() ||
                        startDateMillis == null
                    ) {
                        result.error(
                            "invalid_trip_reminder",
                            "Detail itinerary untuk pengingat tidak valid.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    TripReminderReceiver.saveAndSchedule(
                        this,
                        tripId,
                        destination,
                        startDateMillis,
                    )
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            REQUEST_NOTIFICATION_PERMISSION,
                        )
                        result.success("permission_requested")
                    } else {
                        result.success("scheduled")
                    }
                }
                "cancelTripReminders" -> {
                    val tripId = call.argument<Int>("tripId")
                    if (tripId == null) {
                        result.error(
                            "invalid_trip_id",
                            "ID trip untuk membatalkan pengingat tidak valid.",
                            null,
                        )
                    } else {
                        TripReminderReceiver.cancel(this, tripId)
                        result.success("cancelled")
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PROFILE_PHOTO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickProfilePhoto") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingProfilePhotoResult != null) {
                result.error("picker_busy", "Pemilih foto sedang digunakan.", null)
                return@setMethodCallHandler
            }

            pendingProfilePhotoResult = result
            try {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "image/*"
                }
                startActivityForResult(intent, REQUEST_PROFILE_PHOTO)
            } catch (error: Exception) {
                pendingProfilePhotoResult = null
                result.error("picker_unavailable", "Pemilih foto tidak dapat dibuka.", error.message)
            }
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PROFILE_PHOTO) return

        val result = pendingProfilePhotoResult ?: return
        pendingProfilePhotoResult = null
        if (resultCode != RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.error("photo_missing", "Foto tidak ditemukan.", null)
            return
        }

        try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            val boundsStream = contentResolver.openInputStream(uri)
                ?: throw IllegalStateException("Foto tidak dapat dibaca.")
            boundsStream.use { BitmapFactory.decodeStream(it, null, bounds) }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
                throw IllegalStateException("Format foto tidak didukung.")
            }

            var sampleSize = 1
            while (bounds.outWidth / sampleSize > MAX_PHOTO_DIMENSION ||
                bounds.outHeight / sampleSize > MAX_PHOTO_DIMENSION
            ) {
                sampleSize *= 2
            }
            val options = BitmapFactory.Options().apply { inSampleSize = sampleSize }
            val bitmap = contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it, null, options)
            } ?: throw IllegalStateException("Foto tidak dapat diproses.")

            val bytes = try {
                ByteArrayOutputStream().use { output ->
                    if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 82, output)) {
                        throw IllegalStateException("Foto gagal dikompresi.")
                    }
                    output.toByteArray()
                }
            } finally {
                bitmap.recycle()
            }
            result.success(bytes)
        } catch (error: Exception) {
            result.error("photo_read_failed", "Foto gagal diproses.", error.message)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return

        val notification = pendingVoucherNotification
        pendingVoucherNotification = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED &&
            notification != null
        ) {
            showVoucherNotification(notification.first, notification.second)
        }
    }

    private fun createVoucherNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            notificationChannel,
            "Hadiah LokaCatch",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Notifikasi voucher hadiah dari game LokaCatch"
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun showVoucherNotification(title: String, body: String) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE
                    } else {
                        0
                    },
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, notificationChannel)
        } else {
            Notification.Builder(this)
                .setPriority(Notification.PRIORITY_HIGH)
        }
        builder.setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_EVENT)
            .setAutoCancel(true)

        if (contentIntent != null) {
            builder.setContentIntent(contentIntent)
        }

        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, builder.build())
    }

    companion object {
        private const val REQUEST_NOTIFICATION_PERMISSION = 4102
        private const val REQUEST_PROFILE_PHOTO = 4103
        private const val PROFILE_PHOTO_CHANNEL = "com.example.lokaluxe/profile_photo"
        private const val TRIP_REMINDER_CHANNEL = "com.example.lokaluxe/trip_reminders"
        private const val MAX_PHOTO_DIMENSION = 1280
    }
}
