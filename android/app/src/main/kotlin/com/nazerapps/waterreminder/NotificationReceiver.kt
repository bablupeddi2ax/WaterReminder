package com.nazerapps.waterreminder


import android.annotation.TargetApi
import android.app.AlarmManager
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale


class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val payload = intent.getStringExtra("payload")
        if (action == "DRINK_ACTION") {
            updateWaterIntake(context, 250,intent)
            //cancelNotification(context, intent.getIntExtra("reminderId", 0))
        } else if (action == "SNOOZE_ACTION") {
            snoozeNotification(context, intent.getIntExtra("reminderId", 0))
        }
    }

    @TargetApi(Build.VERSION_CODES.GINGERBREAD)
    private fun updateWaterIntake(context: Context, amount: Int,intent: Intent) {
        try {
            val payload = intent.getStringExtra("payload")?.let { JSONObject(it) }
            val reminderId: Int = payload?.getInt("reminderId") ?: -1
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val today: String = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val currentIntake = prefs.getInt("water_intake_$today", 0)
            val newIntake = currentIntake + amount
            prefs.edit().putInt("water_intake_$today", newIntake).apply()
            Log.d("NotificationReceiver", "Updated water intake: $newIntake ml")
//            cancelNotification(context, reminderId)
        } catch (e: Exception) {
            Log.e("NotificationReceiver", "Error updating water intake: " + e.message)
        }
    }

    @TargetApi(Build.VERSION_CODES.M)
    private fun cancelNotification(context: Context, id: Int) {
        val notificationManager: NotificationManager = context.getSystemService(NotificationManager::class.java) as NotificationManager
        notificationManager.cancel(id)
        Log.d("NotificationReceiver", "Cancelled notification with ID: $id")
    }

    @TargetApi(Build.VERSION_CODES.M)
    private fun snoozeNotification(context: Context, id: Int) {
//        cancelNotification(context, id)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, NotificationReceiver::class.java)
        intent.setAction("DRINK_ACTION")
        intent.putExtra("reminderId", id)
        val pendingIntent =
            PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT)
        val triggerTime = System.currentTimeMillis() + 15 * 60 * 1000
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        Log.d("NotificationReceiver", "Scheduled snooze notification for: " + Date(triggerTime))
    }
}