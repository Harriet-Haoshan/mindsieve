package com.example.mindsieve

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

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
                    "getInstalledApps" -> result.success(getInstalledApps())
                    "isHuaweiDevice" -> result.success(isHuaweiDevice())
                    "openBatterySettings" -> {
                        openBatterySettings()
                        result.success(null)
                    }
                    "hasIgnoreBatteryOptimization" -> result.success(hasIgnoreBatteryOptimization())
                    "openIgnoreBatteryOptimizationSettings" -> {
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                        result.success(null)
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

    /// 获取手机中已安装的「可启动第三方应用」列表
    /// 过滤规则：有桌面图标（LAUNCHER）且非系统预装，排除 MindSieve 自己
    /// 返回：[{packageName, appName, icon(Base64 PNG 或 null)}]，按名称排序
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = pm.queryIntentActivities(launcherIntent, 0)
        val apps = mutableListOf<Map<String, Any?>>()

        for (ri in resolveInfos) {
            val ai = ri.activityInfo.applicationInfo
            // FLAG_SYSTEM 标记系统预装应用，全部排除
            val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (isSystem || ai.packageName == packageName) continue

            apps.add(
                mapOf(
                    "packageName" to ai.packageName,
                    "appName" to ri.loadLabel(pm).toString(),
                    "icon" to drawableToBase64(ri.loadIcon(pm)),
                ),
            )
        }
        return apps.sortedBy { (it["appName"] as String).lowercase() }
    }

    /// 把应用图标 Drawable 渲染成 96x96 PNG 并 Base64 编码（跨通道传输）
    private fun drawableToBase64(drawable: Drawable): String? {
        return try {
            val size = 96
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            null
        }
    }

    /// 是否华为/鸿蒙设备（鸿蒙手机 manufacturer 同样上报 HUAWEI；
    /// 纯血鸿蒙 NEXT 不支持 Android 应用，不在考虑范围）
    private fun isHuaweiDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER ?: ""
        return manufacturer.equals("HUAWEI", ignoreCase = true)
    }

    /// 跳转到本应用的「耗电详情 / 应用启动管理」设置页，引导用户
    /// 打开「允许后台活动」。EMUI 各版本组件名不统一，先尝试直达
    /// 华为手机管家的已知页面，失败则回退到公开的应用详情页
    /// （该页在华为系统上同样包含「耗电详情」「应用启动管理」入口）
    private fun openBatterySettings() {
        val huaweiComponents = listOf(
            // 应用启动管理列表（可设置「允许后台活动」）
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            ),
            // 受保护应用 / 锁屏清理白名单
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity",
            ),
        )
        for (component in huaweiComponents) {
            try {
                val intent = Intent().apply {
                    this.component = component
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return
            } catch (_: Exception) {
                // 该 ROM 版本不存在此 Activity，继续尝试下一个
            }
        }
        // 回退：应用系统详情页（公开 API，所有设备可用）
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    /// 是否已忽略电池优化（即系统不会主动清理本应用后台进程）
    private fun hasIgnoreBatteryOptimization(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }
}
