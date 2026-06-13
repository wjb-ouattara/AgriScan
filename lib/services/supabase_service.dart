import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';
import 'token_service.dart';

// ══════════════════════════════════════════════════════════
//  SUPABASE SERVICE
//  Auth (inscription / connexion / déconnexion)
//  Sync : SQLite local → Supabase cloud
//
//  Configuration :
//  1. Créez un projet sur https://supabase.com (gratuit)
//  2. Copiez l'URL et la clé anon depuis Project Settings
//  3. Remplacez _supabaseUrl et _supabaseKey ci-dessous
//  4. Créez les tables dans Supabase (SQL en bas de fichier)
// ══════════════════════════════════════════════════════════

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // ── Configuration Supabase ────────────────────────────
  // Remplacez par vos vraies valeurs depuis app.supabase.com
  static const String _supabaseUrl = 'https://cuzftcwomzsabuboyfrc.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1emZ0Y3dvbXpzYWJ1Ym95ZnJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3NTc5NDAsImV4cCI6MjA5NTMzMzk0MH0.Vp0NuxTLbN9SQFdWYLZEjoWc86XOOYoFDcXBa-Hr9kc';

  final _db     = DatabaseService();
  final _tokens = TokenService();

  SupabaseClient get _client => Supabase.instance.client;
  User?          get currentUser => _client.auth.currentUser;
  bool           get isConnected => currentUser != null;

  // ══════════════════════════════════════════════════════
  //  INITIALISATION (à appeler dans main.dart)
  // ══════════════════════════════════════════════════════

  static Future<void> initialize() async {
    await Supabase.initialize(
      url  : _supabaseUrl,
      anonKey: _supabaseKey,
    );
  }

  // ══════════════════════════════════════════════════════
  //  INSCRIPTION
  // ══════════════════════════════════════════════════════

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    String region = 'Maroc',
  }) async {
    try {
      // 1. Créer le compte Supabase Auth
      final response = await _client.auth.signUp(
        email   : email,
        password: password,
        data    : {'name': name, 'region': region},
      );

      if (response.user == null) {
        return AuthResult.error('Inscription échouée. Réessayez.');
      }

      // 2. Créer le profil en local SQLite
      final userId = response.user!.id;
      await _db.upsertUser(id: userId, name: name, email: email, region: region);
      await _db.setCurrentUserId(userId);
      await _db.setLoggedIn(true);

      // 3. Créer le profil dans Supabase
      await _client.from('users').upsert({
        'id': userId, 'email': email, 'name': name, 'region': region,
        'is_premium': false, 'scans_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 4. Synchroniser les scans existants
      await _syncLocalScans(userId);
      await _tokens.onLogin();

      return AuthResult.success(
          'Compte créé ! Vos données sont synchronisées.');

    } on AuthException catch (e) {
      return AuthResult.error(_translateAuthError(e.message));
    } catch (e) {
      return AuthResult.error('Erreur : $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //  CONNEXION
  // ══════════════════════════════════════════════════════

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
          email: email, password: password);

      if (response.user == null) {
        return AuthResult.error('Email ou mot de passe incorrect.');
      }

      final userId = response.user!.id;
      final userRow = await getUserProfile(userId);

      // Upsert local avec l'ID Supabase comme ID local (cohérence garantie)
      await _db.upsertUser(
        id    : userId,
        name  : userRow?['name']   ?? '',
        email : userRow?['email']  ?? email,
        region: userRow?['region'] ?? 'Maroc',
      );
      await _db.setCurrentUserId(userId);
      await _db.setLoggedIn(true);

      await _syncLocalScans(userId);
      await _tokens.onLogin();

      return AuthResult.success('Connexion réussie. Bienvenue !');
    } on AuthException catch (e) {
      return AuthResult.error(_translateAuthError(e.message));
    } catch (e) {
      return AuthResult.error('Erreur réseau : $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //  DÉCONNEXION
  // ══════════════════════════════════════════════════════

  Future<void> signOut() async {
    await _client.auth.signOut();
    await _db.logout();
  }

  // ══════════════════════════════════════════════════════
  //  SYNC : SQLite local → Supabase
  //  Envoie tous les scans non encore synchronisés
  // ══════════════════════════════════════════════════════

  Future<SyncResult> syncToCloud() async {
    if (!isConnected) {
      return SyncResult(success: false, synced: 0,
          message: 'Non connecté');
    }

    try {
      final unsynced = await _db.getUnsyncedScans();
      if (unsynced.isEmpty) {
        return SyncResult(success: true, synced: 0,
            message: 'Tout est à jour');
      }

      int syncedCount = 0;
      final userId = currentUser!.id;

      for (final scan in unsynced) {
        try {
          await _client.from('scans').upsert({
            'id'          : scan.id,
            'user_id'     : userId,
            'plant_type'  : scan.plantType,
            'disease_name': scan.diseaseName,
            'severity'    : scan.severity,
            'confidence'  : scan.confidence,
            'model_used'  : scan.modelUsed,
            'created_at'  : scan.createdAt.toIso8601String(),
          });

          // Marquer comme synchronisé localement
          await _db.markScanSynced(scan.id);
          syncedCount++;
        } catch (_) {
          // Continuer même si un scan échoue
        }
      }

      return SyncResult(
        success: true,
        synced : syncedCount,
        message: '$syncedCount analyse${syncedCount > 1 ? "s" : ""} synchronisée${syncedCount > 1 ? "s" : ""}',
      );

    } catch (e) {
      return SyncResult(success: false, synced: 0,
          message: 'Erreur sync : $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //  RÉCUPÉRER L'HISTORIQUE DEPUIS LE CLOUD
  // ══════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getCloudScans({
    int limit = 50,
  }) async {
    if (!isConnected) return [];
    try {
      final result = await _client
          .from('scans')
          .select()
          .eq('user_id', currentUser!.id)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(result);
    } catch (_) {
      return [];
    }
  }

  // ── Sync interne ──────────────────────────────────────
  Future<void> _syncLocalScans(String userId) async {
    final unsynced = await _db.getUnsyncedScans();
    for (final scan in unsynced) {
      try {
        await _client.from('scans').upsert({
          'id'          : scan.id,
          'user_id'     : userId,
          'plant_type'  : scan.plantType,
          'disease_name': scan.diseaseName,
          'severity'    : scan.severity,
          'confidence'  : scan.confidence,
          'model_used'  : scan.modelUsed,
          'created_at'  : scan.createdAt.toIso8601String(),
        });
        await _db.markScanSynced(scan.id);
      } catch (_) {}
    }
  }
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  // ── Traduction erreurs Auth ───────────────────────────
  String _translateAuthError(String msg) {
    if (msg.contains('already registered')) {
      return 'Cet email est déjà utilisé.';
    }
    if (msg.contains('Invalid login')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Confirmez votre email avant de vous connecter.';
    }
    if (msg.contains('weak password') || msg.contains('Password')) {
      return 'Mot de passe trop faible (6 caractères minimum).';
    }
    return 'Erreur d\'authentification. Réessayez.';
  }
}

// ── Modèles ───────────────────────────────────────────────

class AuthResult {
  final bool   success;
  final String message;
  const AuthResult._(this.success, this.message);
  factory AuthResult.success(String msg) => AuthResult._(true,  msg);
  factory AuthResult.error  (String msg) => AuthResult._(false, msg);
}

class SyncResult {
  final bool   success;
  final int    synced;
  final String message;
  const SyncResult({
    required this.success,
    required this.synced,
    required this.message,
  });
}

// ══════════════════════════════════════════════════════════
//  SQL À EXÉCUTER DANS LE DASHBOARD SUPABASE
//  (Project → SQL Editor → New Query → Coller → Run)
// ══════════════════════════════════════════════════════════
//
//  CREATE TABLE users (
//    id           UUID PRIMARY KEY,
//    email        TEXT UNIQUE NOT NULL,
//    name         TEXT,
//    region       TEXT DEFAULT 'Maroc',
//    is_premium   BOOLEAN DEFAULT false,
//    scans_count  INTEGER DEFAULT 0,
//    created_at   TIMESTAMP WITH TIME ZONE DEFAULT now()
//  );
//
//  CREATE TABLE scans (
//    id            UUID PRIMARY KEY,
//    user_id       UUID REFERENCES users(id),
//    plant_type    TEXT,
//    disease_name  TEXT,
//    severity      TEXT,
//    confidence    FLOAT,
//    model_used    TEXT,
//    created_at    TIMESTAMP WITH TIME ZONE DEFAULT now()
//  );
//
//  -- Activer Row Level Security (RLS)
//  ALTER TABLE users ENABLE ROW LEVEL SECURITY;
//  ALTER TABLE scans ENABLE ROW LEVEL SECURITY;
//
//  -- Chaque utilisateur voit seulement ses propres données
//  CREATE POLICY "users_own" ON users
//    FOR ALL USING (auth.uid() = id);
//
//  CREATE POLICY "scans_own" ON scans
//    FOR ALL USING (auth.uid() = user_id);
//
//  -- Vous (admin) voyez TOUT dans le dashboard Supabase
// ══════════════════════════════════════════════════════════