import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'database_service.dart';

// ══════════════════════════════════════════════════════════
//  MEMORY SERVICE — Mémoire auto-alimentée + extractive
//  Enregistre l'historique des scans, le contexte de la ferme,
//  les insights et mémorise intelligemment ce que Gemma juge
//  utile à retenir pour les futures conversations.
// ══════════════════════════════════════════════════════════

// Callback pour générer une réponse via Gemma (injecté depuis l'extérieur)
typedef GemmaResponseCallback = Future<String> Function(String prompt);

class MemoryRecord {
  final String id;
  final String type; // 'scan', 'context', 'insight', 'smart'
  final String key;
  final String value;
  final DateTime date;
  final String metadata;

  const MemoryRecord({
    required this.id,
    required this.type,
    required this.key,
    required this.value,
    required this.date,
    required this.metadata,
  });

  factory MemoryRecord.fromMap(Map<String, dynamic> m) => MemoryRecord(
        id: m['id'] as String,
        type: m['type'] as String? ?? '',
        key: m['key'] as String? ?? '',
        value: m['value'] as String? ?? '',
        date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
        metadata: m['metadata'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'key': key,
        'value': value,
        'date': date.toIso8601String(),
        'metadata': metadata,
      };
}

class MemoryService {
  static final MemoryService _instance = MemoryService._internal();
  factory MemoryService() => _instance;
  MemoryService._internal();

  final _dbService = DatabaseService();
  static const _uuid = Uuid();

  // Callback Gemma injecté depuis le chat service
  GemmaResponseCallback? _gemmaCallback;

  /// Injecter le callback Gemma pour la mémoire extractive.
  /// À appeler une fois depuis ton chat service au démarrage.
  void setGemmaCallback(GemmaResponseCallback callback) {
    _gemmaCallback = callback;
  }

  // ─────────────────────────────────────────────────────────
  //  SCANS
  // ─────────────────────────────────────────────────────────

  /// Enregistre automatiquement un scan dans la mémoire.
  Future<void> recordScan({
    required String plant,
    required String disease,
    required double confidence,
    required String severity,
  }) async {
    final db = await _dbService.db;
    await db.insert('user_memory', {
      'id': _uuid.v4(),
      'type': 'scan',
      'key': plant,
      'value': disease,
      'date': DateTime.now().toIso8601String(),
      'metadata': 'Confidence: ${(confidence * 100).round()}%, Severity: $severity',
    });
  }

  // ─────────────────────────────────────────────────────────
  //  CONTEXTE MANUEL
  // ─────────────────────────────────────────────────────────

  /// Enregistre un élément de contexte manuel (ex: région, type de sol).
  Future<void> recordContext(String key, String value, {String metadata = ''}) async {
    final db = await _dbService.db;

    // Remplacer si la clé existe déjà
    final rows = await db.query(
      'user_memory',
      where: 'type = ? AND key = ?',
      whereArgs: ['context', key],
    );

    if (rows.isNotEmpty) {
      await db.update(
        'user_memory',
        {
          'value': value,
          'date': DateTime.now().toIso8601String(),
          'metadata': metadata,
        },
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    } else {
      await db.insert('user_memory', {
        'id': _uuid.v4(),
        'type': 'context',
        'key': key,
        'value': value,
        'date': DateTime.now().toIso8601String(),
        'metadata': metadata,
      });
    }
  }

  // ─────────────────────────────────────────────────────────
  //  MÉMOIRE EXTRACTIVE INTELLIGENTE (nouvelle)
  // ─────────────────────────────────────────────────────────

  /// Analyse un message utilisateur et décide si une info mérite
  /// d'être mémorisée pour les futures conversations.
  /// À appeler en parallèle après chaque message utilisateur.
  Future<void> analyzeAndMemorize(String userMessage) async {
    if (_gemmaCallback == null) {
      print('⚠️ MemoryService: gemmaCallback non initialisé.');
      return;
    }

    // Récupère les clés déjà mémorisées pour éviter les doublons
    final existingKeys = await _getSmartMemoryKeys();
    final existingKeysStr = existingKeys.isEmpty
        ? 'Aucune pour le moment.'
        : existingKeys.join(', ');

    final prompt = '''
Tu es un assistant agricole intelligent. Analyse ce message d'un agriculteur 
et décide si il contient une information utile à retenir pour les FUTURES conversations.

Une info est utile à mémoriser si elle concerne :
- Un problème qui revient chaque année ou chaque saison
- Une caractéristique permanente ou semi-permanente du champ
- Une contrainte spécifique de l'exploitation
- Une habitude ou pratique récurrente de l'agriculteur
- Un risque identifié propre à son environnement

Une info n'est PAS utile si c'est :
- Une question générale sur une maladie ou un insecte
- Une demande d'information sans lien avec son exploitation
- Une info déjà mémorisée (voir liste ci-dessous)

Infos déjà mémorisées (ne pas dupliquer) : $existingKeysStr

Message de l'agriculteur : "$userMessage"

Réponds UNIQUEMENT en JSON valide, sans texte avant ou après :

Si une info mérite d'être mémorisée :
{
  "memoriser": true,
  "cle": "nom court snake_case de l'info (ex: insecte_récurrent, type_sol)",
  "valeur": "l'info reformulée de façon concise et factuelle",
  "raison": "pourquoi c'est utile à retenir pour les futures conversations"
}

Si rien ne mérite d'être mémorisé :
{
  "memoriser": false
}
''';

    try {
      final response = await _gemmaCallback!(prompt);

      // Nettoyer la réponse (Gemma peut ajouter du texte autour)
      final cleaned = _extractJson(response);
      if (cleaned == null) return;

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      if (json['memoriser'] == true) {
        final key = json['cle'] as String?;
        final value = json['valeur'] as String?;
        final reason = json['raison'] as String?;

        if (key != null && value != null) {
          await _recordSmartMemory(key, value, reason ?? '');
          print('🧠 Mémorisé automatiquement: $key → $value');
          print('   Raison: $reason');
        }
      }
    } catch (e) {
      // Gemma n'a pas retourné de JSON valide — rien à mémoriser
      print('🧠 MemoryService: rien à mémoriser pour ce message ($e)');
    }
  }

  /// Stocke une mémoire extractive intelligente en SQLite.
  Future<void> _recordSmartMemory(String key, String value, String reason) async {
    final db = await _dbService.db;

    // Remplacer si la clé existe déjà
    final rows = await db.query(
      'user_memory',
      where: 'type = ? AND key = ?',
      whereArgs: ['smart', key],
    );

    if (rows.isNotEmpty) {
      await db.update(
        'user_memory',
        {
          'value': value,
          'date': DateTime.now().toIso8601String(),
          'metadata': reason,
        },
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    } else {
      await db.insert('user_memory', {
        'id': _uuid.v4(),
        'type': 'smart',
        'key': key,
        'value': value,
        'date': DateTime.now().toIso8601String(),
        'metadata': reason,
      });
    }
  }

  /// Récupère toutes les clés déjà mémorisées intelligemment.
  Future<List<String>> _getSmartMemoryKeys() async {
    final db = await _dbService.db;
    final rows = await db.query(
      'user_memory',
      columns: ['key'],
      where: 'type = ?',
      whereArgs: ['smart'],
    );
    return rows.map((r) => r['key'] as String).toList();
  }

  /// Récupère toutes les mémoires extractives pour affichage ou debug.
  Future<List<MemoryRecord>> getSmartMemories() async {
    final db = await _dbService.db;
    final rows = await db.query(
      'user_memory',
      where: 'type = ?',
      whereArgs: ['smart'],
      orderBy: 'date DESC',
    );
    return rows.map(MemoryRecord.fromMap).toList();
  }

  /// Supprime une mémoire extractive par clé.
  Future<void> forgetSmartMemory(String key) async {
    final db = await _dbService.db;
    await db.delete(
      'user_memory',
      where: 'type = ? AND key = ?',
      whereArgs: ['smart', key],
    );
    print('🧠 Oublié: $key');
  }

  // ─────────────────────────────────────────────────────────
  //  RÉSUMÉS POUR LE PROMPT GEMMA
  // ─────────────────────────────────────────────────────────

  /// Résumé du contexte manuel de l'exploitation.
  Future<String> getFarmContextSummary() async {
    final db = await _dbService.db;
    final rows = await db.query(
      'user_memory',
      where: 'type = ?',
      whereArgs: ['context'],
    );

    if (rows.isEmpty) return '';

    final buffer = StringBuffer("📍 Contexte de l'exploitation :\n");
    for (final row in rows) {
      buffer.writeln("- ${row['key']}: ${row['value']}");
    }
    return buffer.toString();
  }

  /// Résumé des derniers scans avec détection de récurrences.
  Future<String> getRecentScansSummary({int limit = 5}) async {
    final db = await _dbService.db;
    final rows = await db.query(
      'user_memory',
      where: 'type = ?',
      whereArgs: ['scan'],
      orderBy: 'date DESC',
      limit: limit,
    );

    if (rows.isEmpty) return '';

    final buffer = StringBuffer("🔬 Historique récent des maladies détectées :\n");
    final diseaseCounts = <String, int>{};

    for (final row in rows) {
      final date = DateTime.parse(row['date'] as String);
      final formattedDate = "${date.day}/${date.month}";
      final plant = row['key'] as String;
      final disease = row['value'] as String;
      final metadata = row['metadata'] as String;

      diseaseCounts[disease] = (diseaseCounts[disease] ?? 0) + 1;
      buffer.writeln("- $formattedDate : $disease sur $plant ($metadata)");
    }

    // Ajouter un insight si maladies récurrentes
    final recurrent = diseaseCounts.entries.where((e) => e.value >= 2).toList();
    if (recurrent.isNotEmpty) {
      buffer.writeln("\n⚠️ Motifs récurrents :");
      for (final r in recurrent) {
        buffer.writeln("- '${r.key}' détecté ${r.value} fois récemment.");
      }
    }

    return buffer.toString();
  }

  /// Résumé des mémoires extractives intelligentes.
  Future<String> getSmartMemorySummary() async {
    final db = await _dbService.db;
    final rows = await db.query(
      'user_memory',
      where: 'type = ?',
      whereArgs: ['smart'],
      orderBy: 'date DESC',
    );

    if (rows.isEmpty) return '';

    final buffer = StringBuffer("🧠 Informations mémorisées sur l'exploitation :\n");
    for (final row in rows) {
      buffer.writeln("- ${row['key']}: ${row['value']}");
    }
    return buffer.toString();
  }

  /// Combine tout pour construire le bloc mémoire injecté dans le prompt Gemma.
  Future<String> buildMemoryPromptBlock() async {
    final parts = await Future.wait([
      getFarmContextSummary(),
      getSmartMemorySummary(),
      getRecentScansSummary(),
    ]);

    // Filtrer les blocs vides
    final nonEmpty = parts.where((p) => p.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return '';

    return '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MÉMOIRE ET CONTEXTE DE L'AGRICULTEUR :
${nonEmpty.join('\n')}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
  }

  // ─────────────────────────────────────────────────────────
  //  UTILITAIRES
  // ─────────────────────────────────────────────────────────

  /// Extrait le JSON d'une réponse Gemma qui peut contenir du texte parasite.
  String? _extractJson(String response) {
    // Cherche le premier { et le dernier }
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return response.substring(start, end + 1);
  }

  /// Supprime toute la mémoire (reset complet).
  Future<void> clearAllMemory() async {
    final db = await _dbService.db;
    await db.delete('user_memory');
    print('🧠 Mémoire complètement effacée.');
  }

  /// Supprime uniquement les mémoires d'un type donné.
  Future<void> clearMemoryByType(String type) async {
    final db = await _dbService.db;
    await db.delete('user_memory', where: 'type = ?', whereArgs: [type]);
  }
}