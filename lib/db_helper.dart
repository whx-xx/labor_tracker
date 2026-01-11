import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  // 单例模式：确保全局只有一个数据库连接
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;

  // 获取数据库对象
  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  // 初始化数据库
  Future<Database> _initDb() async {
    // 获取手机存储路径，创建 'labor_tracker.db' 文件
    String path = join(await getDatabasesPath(), 'labor_tracker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. 创建项目表 (projects)
        await db.execute('''
         CREATE TABLE projects(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          default_wage REAL,
          daily_hours REAL, 
          overtime_wage REAL,     -- 模式0时用：每小时多少钱
          overtime_type INTEGER,  -- 新增：0=按金额，1=按工折算
          overtime_divisor REAL,  -- 新增：模式1时用，几小时算1个工
          created_at TEXT
        )
        ''');
        // 2. 创建工时记录表 (work_logs)
        await db.execute('''
          CREATE TABLE work_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER,
            date TEXT,
            regular_hours REAL,   -- 新增：正常上班时间
            overtime_hours REAL,  -- 新增：加班时间
            hours REAL,           -- 总工时 (正常+加班)
            wage REAL,            -- 这里的wage我们存“当日总收入”方便统计
            total_money REAL,     -- 同上，双重保险
            note TEXT,
            FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // --- 下面是增删改查的方法 ---

  // 新建项目
  Future<int> addProject(
    String name,
    double defaultWage,
    double dailyHours,
    double overtimeWage,
    int overtimeType,
    double overtimeDivisor,
  ) async {
    final dbClient = await db;
    return await dbClient.insert('projects', {
      'name': name,
      'default_wage': defaultWage,
      'daily_hours': dailyHours,
      'overtime_wage': overtimeWage,
      'overtime_type': overtimeType, // 新增
      'overtime_divisor': overtimeDivisor, // 新增
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // 获取所有项目
  Future<List<Map<String, dynamic>>> getProjects() async {
    final dbClient = await db;
    // 按创建时间倒序排（新的在前面）
    return await dbClient.query('projects', orderBy: "created_at DESC");
  }

  // 新增工时记录 (带防重复检查)
  Future<int> addWorkLog(int projectId, DateTime date, double regularHours, double overtimeHours, double totalMoney, String note) async {
    final dbClient = await db;
    
    // 1. 先检查当天是否已经有记录了
    String dateStr = date.toIso8601String().split('T')[0];
    final existing = await dbClient.query(
      'work_logs',
      where: 'project_id = ? AND date = ?',
      whereArgs: [projectId, dateStr],
    );

    // 2. 如果已经存在，返回 -1 表示“重复”
    if (existing.isNotEmpty) {
      return -1; 
    }

    // 3. 不存在，才执行插入
    return await dbClient.insert('work_logs', {
      'project_id': projectId,
      'date': dateStr,
      'regular_hours': regularHours,
      'overtime_hours': overtimeHours,
      'hours': regularHours + overtimeHours,
      'wage': totalMoney,
      'total_money': totalMoney,
      'note': note,
    });
  }

  // 获取某个项目的工时记录
  Future<List<Map<String, dynamic>>> getLogsByProject(int projectId) async {
    final dbClient = await db;
    return await dbClient.query(
      'work_logs',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: "date DESC",
    );
  }

  // --- 新增：更新一条工时记录 ---
  Future<int> updateWorkLog(int id, DateTime date, double regularHours, double overtimeHours, double totalMoney, String note) async {
  final dbClient = await db;
  return await dbClient.update(
    'work_logs',
    {
      'date': date.toIso8601String().split('T')[0],
      'regular_hours': regularHours,   // 新增
      'overtime_hours': overtimeHours, // 新增
      'hours': regularHours + overtimeHours,
      'wage': totalMoney,
      'total_money': totalMoney,
      'note': note,
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}

  // --- 新增：删除一条工时记录 ---
  Future<int> deleteWorkLog(int id) async {
    final dbClient = await db;
    return await dbClient.delete('work_logs', where: 'id = ?', whereArgs: [id]);
  }

  // --- 新增：更新项目信息 ---
  Future<int> updateProject(
    int id,
    String name,
    double defaultWage,
    double dailyHours,
    double overtimeWage,
    int overtimeType,
    double overtimeDivisor,
  ) async {
    final dbClient = await db;
    return await dbClient.update(
      'projects',
      {
        'name': name,
        'default_wage': defaultWage,
        'daily_hours': dailyHours,
        'overtime_wage': overtimeWage,
        'overtime_type': overtimeType, // 新增
        'overtime_divisor': overtimeDivisor, // 新增
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- 新增：删除项目 ---
  Future<int> deleteProject(int id) async {
    final dbClient = await db;
    // 先删除该项目下的所有工时记录，防止产生垃圾数据
    await dbClient.delete(
      'work_logs',
      where: 'project_id = ?',
      whereArgs: [id],
    );
    // 再删除项目本身
    return await dbClient.delete('projects', where: 'id = ?', whereArgs: [id]);
  }
}
