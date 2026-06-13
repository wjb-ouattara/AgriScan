import 'database_service.dart';

// ══════════════════════════════════════════════════════════
//  TOKEN SERVICE
//  Gère les 15 scans gratuits hors ligne
//  Déclenche le popup "Créez un compte" au bon moment
// ══════════════════════════════════════════════════════════

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  final _db = DatabaseService();
  static const int _freeLimit = 100;

  // ══════════════════════════════════════════════════════
  //  VÉRIFIER SI L'UTILISATEUR PEUT SCANNER
  // ══════════════════════════════════════════════════════

  Future<ScanPermission> checkPermission() async {
    final isLoggedIn = await _db.isLoggedIn();

    // Connecté → scans illimités
    if (isLoggedIn) {
      final userId = await _db.getCurrentUserId();
      if (userId != null) {
        final user = await _db.getUser(userId);
        if (user != null) {
          return ScanPermission(
            allowed       : true,
            isLoggedIn    : true,
            scansUsed     : user.scansCount,
            scansRemaining: user.scansRemaining,
            isPremium     : user.isPremium,
          );
        }
      }
    }

    // Hors ligne → vérifier le compteur local
    final scansUsed = await _db.getScansUsed();
    final remaining = _freeLimit - scansUsed;

    return ScanPermission(
      allowed       : remaining > 0,
      isLoggedIn    : false,
      scansUsed     : scansUsed,
      scansRemaining: remaining.clamp(0, _freeLimit),
      isPremium     : false,
    );
  }

  // ══════════════════════════════════════════════════════
  //  STATUT POUR L'INTERFACE
  // ══════════════════════════════════════════════════════

  Future<TokenStatus> getStatus() async {
    final permission = await checkPermission();

    if (permission.isLoggedIn && permission.isPremium) {
      return TokenStatus.premium;
    }
    if (permission.isLoggedIn) {
      return TokenStatus.loggedIn;
    }
    if (permission.scansRemaining <= 0) {
      return TokenStatus.limitReached;
    }
    if (permission.scansRemaining <= 3) {
      return TokenStatus.almostLimit;
    }
    return TokenStatus.free;
  }

  // ══════════════════════════════════════════════════════
  //  MESSAGES À AFFICHER
  // ══════════════════════════════════════════════════════

  Future<String> getStatusMessage() async {
    final permission = await checkPermission();

    if (permission.isLoggedIn && permission.isPremium) {
      return 'Compte Premium — Scans illimités ✓';
    }
    if (permission.isLoggedIn) {
      return 'Compte actif — Scans illimités ✓';
    }
    if (permission.scansRemaining <= 0) {
      return 'Limite atteinte — Créez un compte gratuit';
    }
    return '${permission.scansRemaining} analyse${permission.scansRemaining > 1 ? "s" : ""} gratuite${permission.scansRemaining > 1 ? "s" : ""} restante${permission.scansRemaining > 1 ? "s" : ""}';
  }

  // ══════════════════════════════════════════════════════
  //  RÉINITIALISER (après connexion)
  // ══════════════════════════════════════════════════════

  Future<void> onLogin() async {
    // Après connexion, les scans sont illimités
    // Les anciennes données locales seront synchronisées
    await _db.setSetting('scans_used', '0');
  }
}

// ── Modèles ───────────────────────────────────────────────

class ScanPermission {
  final bool allowed;
  final bool isLoggedIn;
  final bool isPremium;
  final int  scansUsed;
  final int  scansRemaining;

  const ScanPermission({
    required this.allowed,
    required this.isLoggedIn,
    required this.isPremium,
    required this.scansUsed,
    required this.scansRemaining,
  });
}

enum TokenStatus {
  free,         // Hors ligne, scans disponibles
  almostLimit,  // Hors ligne, moins de 3 scans restants
  limitReached, // Hors ligne, 0 scans restants
  loggedIn,     // Connecté, illimité
  premium,      // Premium, illimité
}