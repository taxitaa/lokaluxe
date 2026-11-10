package com.example.lokaluxe

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.util.Calendar

class TripReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REMINDER -> showReminder(context, intent)
            ACTION_DAILY_ENGAGEMENT -> {
                context.getSharedPreferences(DAILY_PREFERENCES, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean("scheduled", false)
                    .apply()
                showDailyEngagement(context)
                scheduleNextDailyEngagement(context)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                scheduleStoredReminders(context)
                context.getSharedPreferences(DAILY_PREFERENCES, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean("scheduled", false)
                    .apply()
                scheduleNextDailyEngagement(context)
            }
        }
    }

    companion object {
        const val ACTION_REMINDER = "com.example.lokaluxe.TRIP_REMINDER"
        const val ACTION_DAILY_ENGAGEMENT = "com.example.lokaluxe.DAILY_ENGAGEMENT"
        private const val PREFERENCES = "trip_reminder_preferences"
        private const val CHANNEL_ID = "trip_reminders"
        private const val DAILY_PREFERENCES = "daily_app_notification_preferences"
        private const val DAILY_CHANNEL_ID = "daily_app_engagement"
        private const val DAILY_NOTIFICATION_ID = 20261024
        private const val DAILY_REQUEST_CODE = 20261024
        private const val DAILY_INTERVAL_MILLIS = 3 * 60 * 60 * 1000L
        private val reminderOffsets = listOf(7, 5, 3, 0)
        private val engagementMessages = listOf(
            "Lagi pengin cari inspirasi liburan? Buka LokaLuxe dan temukan destinasi yang cocok buatmu.",
            "Kalau bisa berangkat akhir pekan ini, kamu mau ke mana? Cek ide perjalananmu di LokaLuxe.",
            "Sedikit waktu buat rencana seru? Yuk, intip destinasi dan itinerary di LokaLuxe.",
            "Pantai, alam, atau kuliner lokal—lagi ingin yang mana? Temukan inspirasinya di LokaLuxe.",
            "Rencana liburanmu sudah siap? Buka LokaLuxe untuk lanjut atur itinerary dan budget.",
            "Butuh ide buat perjalanan berikutnya? LokaLuxe siap bantu kamu mulai merencanakannya.",
        )

        fun scheduleDailyEngagement(context: Context) {
            if (!canPostNotifications(context)) return

            val preferences = context.getSharedPreferences(DAILY_PREFERENCES, Context.MODE_PRIVATE)
            preferences.edit().putBoolean("enabled", true).apply()
            if (preferences.getBoolean("scheduled", false)) return
            scheduleNextDailyEngagement(context)
        }

        fun saveAndSchedule(
            context: Context,
            tripId: Int,
            destination: String,
            startDateMillis: Long,
        ): Int {
            cancelStoredReminders(context)
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .edit()
                .putInt("tripId", tripId)
                .putString("destination", destination)
                .putLong("startDateMillis", startDateMillis)
                .apply()
            return schedule(context, tripId, startDateMillis)
        }

        fun cancel(context: Context, tripId: Int) {
            cancelAlarms(context, tripId)
            val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            if (preferences.getInt("tripId", -1) == tripId) {
                preferences.edit().clear().apply()
            }
        }

        private fun scheduleStoredReminders(context: Context) {
            val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            val tripId = preferences.getInt("tripId", -1)
            val destination = preferences.getString("destination", null)
            val startDateMillis = preferences.getLong("startDateMillis", 0)
            if (tripId < 0 || destination.isNullOrBlank() || startDateMillis <= 0) return
            schedule(context, tripId, startDateMillis)
        }

        private fun scheduleNextDailyEngagement(context: Context) {
            val preferences = context.getSharedPreferences(DAILY_PREFERENCES, Context.MODE_PRIVATE)
            if (!preferences.getBoolean("enabled", false) || !canPostNotifications(context)) {
                return
            }

            val alarmManager = context.getSystemService(AlarmManager::class.java)
            val triggerAtMillis = System.currentTimeMillis() + DAILY_INTERVAL_MILLIS
            val alarm = dailyPendingIntent(context)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    alarm,
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, alarm)
            }
            preferences.edit().putBoolean("scheduled", true).apply()
        }

        private fun canPostNotifications(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED

        private fun dailyPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, TripReminderReceiver::class.java)
                .setAction(ACTION_DAILY_ENGAGEMENT)
            return PendingIntent.getBroadcast(
                context,
                DAILY_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }),
            )
        }

        private fun cancelStoredReminders(context: Context) {
            val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            val oldTripId = preferences.getInt("tripId", -1)
            if (oldTripId >= 0) cancelAlarms(context, oldTripId)
        }

        private fun cancelAlarms(context: Context, tripId: Int) {
            val alarmManager = context.getSystemService(AlarmManager::class.java)
            reminderOffsets.forEach { offset ->
                alarmManager.cancel(pendingIntent(context, tripId, offset))
            }
        }

        private fun schedule(
            context: Context,
            tripId: Int,
            startDateMillis: Long,
        ): Int {
            val alarmManager = context.getSystemService(AlarmManager::class.java)
            val now = System.currentTimeMillis()
            var scheduledCount = 0
            reminderOffsets.forEach { offset ->
                val calendar = Calendar.getInstance().apply {
                    timeInMillis = startDateMillis
                    add(Calendar.DAY_OF_MONTH, -offset)
                    set(Calendar.HOUR_OF_DAY, 9)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                if (calendar.timeInMillis <= now) return@forEach

                val alarm = pendingIntent(context, tripId, offset)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        alarm,
                    )
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, alarm)
                }
                scheduledCount++
            }
            return scheduledCount
        }

        private fun pendingIntent(context: Context, tripId: Int, offset: Int): PendingIntent {
            val intent = Intent(context, TripReminderReceiver::class.java)
                .setAction(ACTION_REMINDER)
                .putExtra("tripId", tripId)
                .putExtra("offset", offset)
            return PendingIntent.getBroadcast(
                context,
                tripId * 10 + offset,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                ) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }),
            )
        }

        private fun showReminder(context: Context, intent: Intent) {
            val tripId = intent.getIntExtra("tripId", -1)
            val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            if (tripId < 0 || preferences.getInt("tripId", -1) != tripId) return

            val destination = preferences.getString("destination", null) ?: return
            val offset = intent.getIntExtra("offset", 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
            val body = if (offset == 0) {
                "Perjalananmu ke $destination dimulai hari ini. Buka LokaLuxe untuk cek itinerary."
            } else {
                "Perjalananmu ke $destination dimulai $offset hari lagi. Buka LokaLuxe untuk cek itinerary dan budget."
            }
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Pengingat perjalanan",
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ).apply {
                        description = "Pengingat itinerary dan budget perjalanan"
                    },
                )
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val contentIntent = launchIntent?.let {
                PendingIntent.getActivity(
                    context,
                    tripId,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                    ) {
                        PendingIntent.FLAG_IMMUTABLE
                    } else {
                        0
                    }),
                )
            }
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                Notification.Builder(context).setPriority(Notification.PRIORITY_DEFAULT)
            }
            builder.setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Pengingat perjalanan LokaLuxe")
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setCategory(Notification.CATEGORY_EVENT)
                .setAutoCancel(true)
            if (contentIntent != null) builder.setContentIntent(contentIntent)
            manager.notify(tripId * 10 + offset, builder.build())
        }

        private fun showDailyEngagement(context: Context) {
            if (!canPostNotifications(context)) return

            val preferences = context.getSharedPreferences(DAILY_PREFERENCES, Context.MODE_PRIVATE)
            if (!preferences.getBoolean("enabled", false)) return
            val messageIndex = preferences.getInt("messageIndex", 0) % engagementMessages.size
            val body = engagementMessages[messageIndex]
            preferences.edit().putInt("messageIndex", messageIndex + 1).apply()

            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        DAILY_CHANNEL_ID,
                        "Inspirasi LokaLuxe",
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ).apply {
                        description = "Pengingat berkala untuk membuka LokaLuxe"
                    },
                )
            }

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val contentIntent = launchIntent?.let {
                PendingIntent.getActivity(
                    context,
                    DAILY_REQUEST_CODE,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                    ) {
                        PendingIntent.FLAG_IMMUTABLE
                    } else {
                        0
                    }),
                )
            }
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, DAILY_CHANNEL_ID)
            } else {
                Notification.Builder(context).setPriority(Notification.PRIORITY_DEFAULT)
            }
            builder.setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Ada ide perjalanan buatmu")
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setCategory(Notification.CATEGORY_REMINDER)
                .setAutoCancel(true)

            if (contentIntent != null) {
                builder.setContentIntent(contentIntent)
                builder.addAction(
                    Notification.Action.Builder(
                        android.R.drawable.ic_menu_view,
                        "Buka LokaLuxe",
                        contentIntent,
                    ).build(),
                )
            }
            manager.notify(DAILY_NOTIFICATION_ID, builder.build())
        }

    }
}
