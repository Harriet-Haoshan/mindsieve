import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/app_stats.dart';

class AppDao {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mindsieve.db');
    return await openDatabase(
      path,
      version: 2,
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
            enabled INTEGER DEFAULT 1,
            added_time INTEGER
          )''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''CREATE TABLE controlled_apps(
              id INTEGER PRIMARY KEY,
              package_name TEXT UNIQUE,
              app_name TEXT,
              enabled INTEGER DEFAULT 1,
              added_time INTEGER
            )''');
        }
      },
    );
  }

  Future<void> logAppOpen(String packageName, String appName) async {
    final db = await database;
    await db.insert('usage_logs', {
      'package_name': packageName,
      'app_name': appName,
      'start_time': DateTime.now().millisecondsSinceEpoch,
      'duration': 0,
    });
  }

  Future<void> updateDuration(int logId, int durationInSeconds) async {
    final db = await database;
    await db.update(
      'usage_logs',
      {'duration': durationInSeconds},
      where: 'id = ?',
      whereArgs: [logId],
    );
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
        package_name,
        app_name,
        SUM(duration) as total_duration,
        COUNT(*) as open_count
      FROM usage_logs
      WHERE start_time > ? AND duration > 0
      GROUP BY package_name
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

  Future<List<Map<String, dynamic>>> getControlledApps() async {
    final db = await database;
    return await db.query('controlled_apps', orderBy: 'app_name');
  }

  Future<void> addControlledApp(String packageName, String appName) async {
    final db = await database;
    await db.insert('controlled_apps', {
      'package_name': packageName,
      'app_name': appName,
      'enabled': 1,
      'added_time': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeControlledApp(String packageName) async {
    final db = await database;
    await db.delete(
      'controlled_apps',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  Future<void> toggleControlledApp(String packageName) async {
    final db = await database;
    final result = await db.query(
      'controlled_apps',
      columns: ['enabled'],
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
    if (result.isNotEmpty) {
      final current = result.first['enabled'] as int;
      await db.update(
        'controlled_apps',
        {'enabled': current == 1 ? 0 : 1},
        where: 'package_name = ?',
        whereArgs: [packageName],
      );
    }
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
