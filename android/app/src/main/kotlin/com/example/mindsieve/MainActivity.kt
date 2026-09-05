package com.example.mindsieve

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "mindsieve/usage"
        // UsageEvents 事件类型：进入前台 / 退到后台
        private const val EVENT_FOREGROUND = 1 // MOVE_TO_FOREGROUND / ACTIVITY_RESUMED
        private const val EVENT_BACKGROUND = 2 // MOVE_TO_BACKGROUND / ACTIVITY_PAUSED
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "queryUsageEvents" -> {
                        val start = (call.argument<Number>("start"))?.toLong() ?: 0L
                        val end = (call.argument<Number>("end"))?.toLong()
                            ?: System.currentTimeMillis()
                        result.success(queryUsageEvents(start, end))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// 是否拥有「使用情况访问权限」（需用户在系统设置中手动授予）
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        // OPSTR_GET_USAGE_STATS = "android:get_usage_stats"（API 23+ 公开常量，
        // 旧的 int 型 OP_USAGE_ACCESS 为 @hide，应用层不可引用）
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /// 查询 [start, end] 时间段内的前后台切换事件
    /// 返回：[{packageName, eventType, timestamp}]
    private fun queryUsageEvents(start: Long, end: Long): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(start, end)
        val list = mutableListOf<Map<String, Any>>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == EVENT_FOREGROUND || event.eventType == EVENT_BACKGROUND) {
                list.add(
                    mapOf(
                        "packageName" to event.packageName,
                        "eventType" to event.eventType,
                        "timestamp" to event.timeStamp,
                    ),
                )
            }
        }
        return list
    }
}
