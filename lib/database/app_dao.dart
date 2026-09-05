import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/app_stats.dart';

class AppDao {
  static Database? _database;

  /// 预设监控 App（简洁模式：固定列表，用户只需打开/关闭开关）
  static const List<({String packageName, String appName})> presetApps = [
    (packageName: 'com.ss.android.ugc.aweme', appName: '抖音'),
    (packageName: 'com.xingin.xhs', appName: '小红书'),
    (packageName: 'tv.danmaku.bili', appName: 'B站'),
    (packageName: 'com.tencent.mm', appName: '微信'),
    (packageName: 'com.sina.weibo', appName: '微博'),
    (packageName: 'com.zhiliaoapp.musically', appName: 'TikTok'),
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mindsieve.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE notes(id INTEGER PRIMARY KEY, content TEXT, timestamp INTEGER)',
        );
        await db.execute('''CREATE TABLE usage_logs(
            id INTEGER PRIMARY KEY,
            package_name TEXT,
            app_name TEXT,
            start_time INTEGER,
            duration INTEGER
          )''');
        await db.execute('''CREATE TABLE controlled_apps(
            id INTEGER PRIMARY KEY,
            package_name TEXT UNIQUE,
            app_name TEXT,
            nickname TEXT,
            enabled INTEGER DEFAULT 1,
            added_time INTEGER
          )''');
        await db.execute('''CREATE TABLE meta(
            key TEXT PRIMARY KEY,
            value TEXT
          )''');
        // 新装用户：写入预设监控 App（默认全部开启）
        await _seedPresetApps(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''CREATE TABLE controlled_apps(
              id INTEGER PRIMARY KEY,
              package_name TEXT UNIQUE,
              app_name TEXT,
              nickname TEXT,
              enabled INTEGER DEFAULT 1,
              added_time INTEGER
            )''');
        }
        if (oldVersion < 3) {
          // v3：App 昵称 + 键值元数据表（记录事件同步游标）
          await db.execute(
            'ALTER TABLE controlled_apps ADD COLUMN nickname TEXT',
          );
          await db.execute('''CREATE TABLE IF NOT EXISTS meta(
              key TEXT PRIMARY KEY,
              value TEXT
            )''');
        }
        if (oldVersion < 4) {
          // v4：恢复简洁模式——固定预设 App 列表 + 开关。
          // 补齐缺失的预设 App（保留已有开关状态），移除手动添加/测试
          // 产生的多余行，并清空昵称（简洁模式不再提供昵称编辑）
          await _seedPresetApps(db);
          final presetPackages = presetApps.map((a) => a.packageName).toList();
          final placeholders = List.filled(
            presetPackages.length,
            '?',
          ).join(',');
          await db.delete(
            'controlled_apps',
            where: 'package_name NOT IN ($placeholders)',
            whereArgs: presetPackages,
          );
          await db.rawUpdate('UPDATE controlled_apps SET nickname = NULL');
        }
      },
    );
  }

  /// 写入预设监控 App；已存在的行跳过（保留用户的开关状态）
  static Future<void> _seedPresetApps(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final app in presetApps) {
      await db.insert('controlled_apps', {
        'package_name': app.packageName,
        'app_name': app.appName,
        'enabled': 1,
        'added_time': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ========== 使用记录 ==========

  /// 直接写入一条已完成的使用记录（前台监控事件回放时调用）
  Future<void> insertUsageLog(
    String packageName,
    String appName,
    int startMs,
    int durationInSeconds,
  ) async {
    final db = await database;
    await db.insert('usage_logs', {
      'package_name': packageName,
      'app_name': appName,
      'start_time': startMs,
      'duration': durationInSeconds,
    });
  }

  Future<int> getTodayUsage(String packageName) async {
    final db = await database;
    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      '''
      SELECT SUM(duration) as total
      FROM usage_logs
      WHERE package_name = ? AND start_time > ?
    ''',
      [packageName, startOfDay],
    );

    return result.first['total'] as int? ?? 0;
  }

  Future<int> getTodayTotalUsage() async {
    final db = await database;
    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      '''
      SELECT SUM(duration) as total
      FROM usage_logs
      WHERE start_time > ?
    ''',
      [startOfDay],
    );

    return result.first['total'] as int? ?? 0;
  }

  Future<List<AppUsageStats>> getTodayTopApps() async {
    final db = await database;
    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      '''
      SELECT
        u.package_name,
        COALESCE(NULLIF(ca.nickname, ''), u.app_name) as app_name,
        SUM(u.duration) as total_duration,
        COUNT(*) as open_count
      FROM usage_logs u
      LEFT JOIN controlled_apps ca ON ca.package_name = u.package_name
      WHERE u.start_time > ? AND u.duration > 0
      GROUP BY u.package_name
      ORDER BY total_duration DESC
    ''',
      [startOfDay],
    );

    return result
        .map(
          (row) => AppUsageStats(
            packageName: row['package_name'] as String,
            appName: row['app_name'] as String,
            totalDuration: row['total_duration'] as int? ?? 0,
            openCount: row['open_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<List<HourlyStats>> getTodayHourlyDistribution() async {
    final db = await database;
    final startOfDay = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      '''
      SELECT
        strftime('%H', datetime(start_time/1000, 'unixepoch', 'localtime')) as hour,
        SUM(duration) as total_duration,
        COUNT(*) as open_count
      FROM usage_logs
      WHERE start_time > ? AND duration > 0
      GROUP BY hour
      ORDER BY hour
    ''',
      [startOfDay],
    );

    return result
        .map(
          (row) => HourlyStats(
            hour: int.parse(row['hour'] as String),
            duration: row['total_duration'] as int? ?? 0,
            openCount: row['open_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  // ========== 统计复盘聚合查询 ==========

  /// 某天按「小时 × App」分组的使用时长（秒），用于 24 小时堆叠色块图
  /// app_name 为昵称优先的显示名
  Future<List<HourlyAppUsage>> getHourlyAppUsage(int startMs, int endMs) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%H', datetime(start_time/1000, 'unixepoch', 'localtime')) AS INTEGER) as hour,
        u.package_name,
        COALESCE(NULLIF(ca.nickname, ''), u.app_name) as app_name,
        SUM(u.duration) as total_duration
      FROM usage_logs u
      LEFT JOIN controlled_apps ca ON ca.package_name = u.package_name
      WHERE u.start_time >= ? AND u.start_time < ? AND u.duration > 0
      GROUP BY hour, u.package_name
      ORDER BY hour
    ''',
      [startMs, endMs],
    );

    return result
        .map(
          (row) => HourlyAppUsage(
            hour: row['hour'] as int,
            packageName: row['package_name'] as String,
            appName: row['app_name'] as String,
            duration: row['total_duration'] as int? ?? 0,
          ),
        )
        .toList();
  }

  /// 区间内按「天」汇总的使用时长（秒），key 为 yyyy-MM-dd（本地时区）
  Future<Map<String, int>> getDailyTotals(int startMs, int endMs) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT
        strftime('%Y-%m-%d', datetime(start_time/1000, 'unixepoch', 'localtime')) as day,
        SUM(duration) as total_duration
      FROM usage_logs
      WHERE start_time >= ? AND start_time < ? AND duration > 0
      GROUP BY day
    ''',
      [startMs, endMs],
    );

    return {
      for (final row in result)
        row['day'] as String: row['total_duration'] as int? ?? 0,
    };
  }

  /// 区间内按「月」汇总的使用时长（秒），key 为 yyyy-MM（本地时区）
  Future<Map<String, int>> getMonthlyTotals(int startMs, int endMs) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT
        strftime('%Y-%m', datetime(start_time/1000, 'unixepoch', 'localtime')) as month,
        SUM(duration) as total_duration
      FROM usage_logs
      WHERE start_time >= ? AND start_time < ? AND duration > 0
      GROUP BY month
    ''',
      [startMs, endMs],
    );

    return {
      for (final row in result)
        row['month'] as String: row['total_duration'] as int? ?? 0,
    };
  }

  // ========== 被监控 App ==========

  Future<List<Map<String, dynamic>>> getControlledApps() async {
    final db = await database;
    return await db.query('controlled_apps', orderBy: 'app_name');
  }

  /// 查询单个已启用（enabled=1）的被监控 App；不存在或未启用返回 null
  Future<Map<String, dynamic>?> getControlledApp(String packageName) async {
    final db = await database;
    final result = await db.query(
      'controlled_apps',
      where: 'package_name = ? AND enabled = 1',
      whereArgs: [packageName],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  /// 设置预设 App 的监控开关（简洁模式下唯一的写操作）
  Future<void> setAppEnabled(String packageName, bool enabled) async {
    final db = await database;
    await db.update(
      'controlled_apps',
      {'enabled': enabled ? 1 : 0},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  Future<bool> isControlled(String packageName) async {
    final db = await database;
    final result = await db.query(
      'controlled_apps',
      columns: ['enabled'],
      where: 'package_name = ? AND enabled = 1',
      whereArgs: [packageName],
    );
    return result.isNotEmpty;
  }

  // ========== 元数据（键值对） ==========

  Future<String?> getMeta(String key) async {
    final db = await database;
    final result = await db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return result.isEmpty ? null : result.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ========== 测试专用方法 ==========
  // 注意：以下方法仅用于开发和测试阶段，正式发布前需要删除

  /// 测试用：写入一条模拟使用记录
  Future<void> addMockUsage(
    String packageName,
    String appName,
    int durationInSeconds,
  ) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('usage_logs', {
      'package_name': packageName,
      'app_name': appName,
      'start_time': now - 3600000,
      'duration': durationInSeconds,
    });
  }

  Future<void> clearAllUsage() async {
    final db = await database;
    await db.delete('usage_logs');
  }
}
