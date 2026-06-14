import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════
//  DATABASE SERVICE — SQLite local
//  Fonctionne 100% hors ligne
//  Stocke : users, scans, recommendations, settings
// ══════════════════════════════════════════════════════════

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;
  static const String _dbName    = 'agriscan.db';
  static const int    _dbVersion = 2;
  static const _uuid  = Uuid();

  // ── Accès base de données ─────────────────────────────
  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Migration : ajoute les nouvelles tables/colonnes sans
  //    effacer les données existantes
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS knowledge_docs (
        id         TEXT PRIMARY KEY,
        title      TEXT,
        content    TEXT,
        source     TEXT,
        tags       TEXT,
        created_at TEXT
      )
    ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS chat_messages (
        id         TEXT PRIMARY KEY,
        role       TEXT,
        content    TEXT,
        sources    TEXT,
        created_at TEXT
      )
    ''');

      // SQLite n'autorise pas "ADD COLUMN IF NOT EXISTS" — on tente
      // et on ignore l'erreur si la colonne existe déjà.
      try {
        await db.execute('ALTER TABLE scans ADD COLUMN custom_label TEXT');
      } catch (_) {}
    }
  }

  // ── Création des tables ───────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id           TEXT PRIMARY KEY,
        email        TEXT UNIQUE,
        name         TEXT,
        region       TEXT DEFAULT "Maroc",
        is_premium   INTEGER DEFAULT 0,
        scans_count  INTEGER DEFAULT 0,
        scans_limit  INTEGER DEFAULT 15,
        created_at   TEXT,
        synced       INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE scans (
        id            TEXT PRIMARY KEY,
        user_id       TEXT,
        plant_type    TEXT,
        disease_name  TEXT,
        severity      TEXT,
        confidence    REAL,
        model_used    TEXT,
        image_path    TEXT,
        latitude      REAL,
        longitude     REAL,
        synced        INTEGER DEFAULT 0,
        created_at    TEXT,
        custom_label  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE recommendations (
        id           TEXT PRIMARY KEY,
        scan_id      TEXT,
        ai_response  TEXT,
        created_at   TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key   TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Insérer paramètres par défaut
    await db.insert('app_settings',
        {'key': 'scans_used', 'value': '0'});
    await db.insert('app_settings',
        {'key': 'is_logged_in', 'value': 'false'});
    await db.insert('app_settings',
        {'key': 'user_id', 'value': ''});

    await db.execute('''
      CREATE TABLE knowledge_docs (
        id         TEXT PRIMARY KEY,
        title      TEXT,
        content    TEXT,
        source     TEXT,
        tags       TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id         TEXT PRIMARY KEY,
        role       TEXT,
        content    TEXT,
        sources    TEXT,
        created_at TEXT
      )
    ''');
  }


  // ══════════════════════════════════════════════════════
  //  USERS
  // ══════════════════════════════════════════════════════

  Future<AppUser?> getUser(String userId) async {
    final database = await db;
    final rows = await database.query(
        'users', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final database = await db;
    final rows = await database.query(
        'users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<String> createUser({
    required String name,
    required String email,
    String region = 'Maroc',
  }) async {
    final database = await db;
    final id = _uuid.v4();
    await database.insert('users', {
      'id'        : id,
      'email'     : email,
      'name'      : name,
      'region'    : region,
      'is_premium': 0,
      'scans_count': 0,
      'scans_limit': 15,
      'created_at': DateTime.now().toIso8601String(),
      'synced'    : 0,
    });
    await setSetting('user_id', id);
    await setSetting('is_logged_in', 'true');
    return id;
  }
  // ── Upsert avec ID imposé (= ID Supabase) ─────────────
  Future<void> upsertUser({
    required String id,
    required String name,
    required String email,
    String region = 'Maroc',
  }) async {
    final database = await db;
    final existing = await getUser(id);
    if (existing == null) {
      await database.insert('users', {
        'id'         : id,
        'email'      : email,
        'name'       : name,
        'region'     : region,
        'is_premium' : 0,
        'scans_count': 0,
        'scans_limit': 15,
        'created_at' : DateTime.now().toIso8601String(),
        'synced'     : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await database.update('users', {
        'name'  : name,
        'email' : email,
        'region': region,
      }, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> setCurrentUserId(String userId) async {
    await setSetting('user_id', userId);
  }

  Future<void> setLoggedIn(bool value) async {
    await setSetting('is_logged_in', value ? 'true' : 'false');
  }

  Future<void> updateUser(AppUser user) async {
    final database = await db;
    await database.update(
        'users', user.toMap(),
        where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> setPremium(String userId, bool isPremium) async {
    final database = await db;
    await database.update(
      'users',
      {
        'is_premium' : isPremium ? 1 : 0,
        'scans_limit': isPremium ? 999999 : 15,
      },
      where: 'id = ?', whereArgs: [userId],
    );
  }

  // ══════════════════════════════════════════════════════
  //  SCANS
  // ══════════════════════════════════════════════════════

  Future<String> saveScan({
    required String plantType,
    required String diseaseName,
    required String severity,
    required double confidence,
    required String modelUsed,
    String?  userId,
    String?  imagePath,
    double?  latitude,
    double?  longitude,
  }) async {
    final database = await db;
    final id = _uuid.v4();
    await database.insert('scans', {
      'id'          : id,
      'user_id'     : userId ?? '',
      'plant_type'  : plantType,
      'disease_name': diseaseName,
      'severity'    : severity,
      'confidence'  : confidence,
      'model_used'  : modelUsed,
      'image_path'  : imagePath ?? '',
      'latitude'    : latitude,
      'longitude'   : longitude,
      'synced'      : 0,
      'created_at'  : DateTime.now().toIso8601String(),
    });

    // Incrémenter le compteur
    await _incrementScansUsed();

    // Incrémenter le compteur de l'utilisateur si connecté
    if (userId != null && userId.isNotEmpty) {
      await database.rawUpdate(
        'UPDATE users SET scans_count = scans_count + 1 WHERE id = ?',
        [userId],
      );
    }

    return id;
  }

  Future<List<ScanRecord>> getScans({
    String? userId,
    int limit = 50,
  }) async {
    final database = await db;
    final rows = userId != null
        ? await database.query('scans',
        where   : 'user_id = ?',
        whereArgs: [userId],
        orderBy : 'created_at DESC',
        limit   : limit)
        : await database.query('scans',
        orderBy: 'created_at DESC',
        limit  : limit);
    return rows.map(ScanRecord.fromMap).toList();
  }

  Future<List<ScanRecord>> getUnsyncedScans() async {
    final database = await db;
    final rows = await database.query(
        'scans', where: 'synced = 0');
    return rows.map(ScanRecord.fromMap).toList();
  }

  Future<void> markScanSynced(String scanId) async {
    final database = await db;
    await database.update(
        'scans', {'synced': 1},
        where: 'id = ?', whereArgs: [scanId]);
  }

  Future<int> getScansCount() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as count FROM scans');
    return Sqflite.firstIntValue(result) ?? 0;
  }
  Future<void> updateScanLabel(String scanId, String? label) async {
    final database = await db;
    await database.update('scans', {'custom_label': label},
        where: 'id = ?', whereArgs: [scanId]);
  }

  Future<void> deleteScan(String scanId) async {
    final database = await db;
    await database.delete('scans', where: 'id = ?', whereArgs: [scanId]);
    await database.delete('recommendations', where: 'scan_id = ?', whereArgs: [scanId]);
  }

  // ══════════════════════════════════════════════════════
  //  RECOMMENDATIONS
  // ══════════════════════════════════════════════════════

  Future<void> saveRecommendation({
    required String scanId,
    required String aiResponseJson,
  }) async {
    final database = await db;
    await database.insert('recommendations', {
      'id'         : _uuid.v4(),
      'scan_id'    : scanId,
      'ai_response': aiResponseJson,
      'created_at' : DateTime.now().toIso8601String(),
    });
  }

  Future<String?> getRecommendation(String scanId) async {
    final database = await db;
    final rows = await database.query(
        'recommendations',
        where: 'scan_id = ?', whereArgs: [scanId]);
    if (rows.isEmpty) return null;
    return rows.first['ai_response'] as String?;
  }

  // ══════════════════════════════════════════════════════
  //  SETTINGS
  // ══════════════════════════════════════════════════════

  Future<String?> getSetting(String key) async {
    final database = await db;
    final rows = await database.query(
        'app_settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final database = await db;
    await database.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Helpers compteur scans ────────────────────────────
  Future<void> _incrementScansUsed() async {
    final current = int.tryParse(
        await getSetting('scans_used') ?? '0') ?? 0;
    await setSetting('scans_used', '${current + 1}');
  }

  Future<int> getScansUsed() async {
    return int.tryParse(
        await getSetting('scans_used') ?? '0') ?? 0;
  }

  Future<bool> isLoggedIn() async {
    return (await getSetting('is_logged_in')) == 'true';
  }

  Future<String?> getCurrentUserId() async {
    final id = await getSetting('user_id');
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> logout() async {
    await setSetting('is_logged_in', 'false');
    await setSetting('user_id', '');
  }

  // ── Reset complet (debug) ─────────────────────────────
  Future<void> clearAll() async {
    final database = await db;
    await database.delete('scans');
    await database.delete('recommendations');
    await setSetting('scans_used', '0');
    await setSetting('is_logged_in', 'false');
    await setSetting('user_id', '');
  }
}


// ══════════════════════════════════════════════════════════
//  MODÈLES DE DONNÉES
// ══════════════════════════════════════════════════════════

class AppUser {
  final String  id;
  final String? email;
  final String? name;
  final String  region;
  final bool    isPremium;
  final int     scansCount;
  final int     scansLimit;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    this.email,
    this.name,
    this.region     = 'Maroc',
    this.isPremium  = false,
    this.scansCount = 0,
    this.scansLimit = 15,
    required this.createdAt,
  });

  bool get hasScansRemaining =>
      isPremium || scansCount < scansLimit;

  int get scansRemaining =>
      isPremium ? 999 : (scansLimit - scansCount).clamp(0, scansLimit);

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    id         : m['id'],
    email      : m['email'],
    name       : m['name'],
    region     : m['region'] ?? 'Maroc',
    isPremium  : (m['is_premium'] as int? ?? 0) == 1,
    scansCount : m['scans_count'] as int? ?? 0,
    scansLimit : m['scans_limit'] as int? ?? 15,
    createdAt  : DateTime.parse(
        m['created_at'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id'         : id,
    'email'      : email,
    'name'       : name,
    'region'     : region,
    'is_premium' : isPremium ? 1 : 0,
    'scans_count': scansCount,
    'scans_limit': scansLimit,
    'created_at' : createdAt.toIso8601String(),
  };
}

class ScanRecord {
  final String   id;
  final String   plantType;
  final String   diseaseName;
  final String   severity;
  final double   confidence;
  final String   modelUsed;
  final String?  imagePath;
  final bool     synced;
  final DateTime createdAt;
  final String? customLabel;

  const ScanRecord({
    required this.id,
    required this.plantType,
    required this.diseaseName,
    required this.severity,
    required this.confidence,
    required this.modelUsed,
    this.imagePath,
    this.synced    = false,
    required this.createdAt,
    this.customLabel,
  });

  factory ScanRecord.fromMap(Map<String, dynamic> m) => ScanRecord(
    id          : m['id'],
    plantType   : m['plant_type']   ?? '',
    diseaseName : m['disease_name'] ?? '',
    severity    : m['severity']     ?? '',
    confidence  : (m['confidence']  as num?)?.toDouble() ?? 0.0,
    modelUsed   : m['model_used']   ?? '',
    imagePath   : m['image_path'],
    synced      : (m['synced'] as int? ?? 0) == 1,
    createdAt   : DateTime.parse(
        m['created_at'] ?? DateTime.now().toIso8601String()),
    customLabel : m['custom_label'] as String?,
  );
}