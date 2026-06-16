import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';
import '../data/knowledge_seed.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

// ══════════════════════════════════════════════════════════
//  KNOWLEDGE BASE SERVICE — RAG léger (100% hors ligne)
//  Stocke les documents dans SQLite et propose une recherche
//  par pertinence (TF-IDF) sans dépendance à une API
//  d'embeddings externe.
// ══════════════════════════════════════════════════════════

class KnowledgeDocument {
  final String id;
  final String title;
  final String content;
  final String source;       // 'seed' | 'import:<fichier>' | 'manual'
  final List<String> tags;
  final DateTime createdAt;

  const KnowledgeDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.source,
    required this.tags,
    required this.createdAt,
  });

  bool get isSeed => source == 'seed';

  factory KnowledgeDocument.fromMap(Map<String, dynamic> m) => KnowledgeDocument(
    id     : m['id'] as String,
    title  : m['title'] as String? ?? '',
    content: m['content'] as String? ?? '',
    source : m['source'] as String? ?? 'manual',
    tags   : (m['tags'] as String? ?? '')
        .split(',').where((t) => t.isNotEmpty).toList(),
    createdAt: DateTime.parse(
        m['created_at'] as String? ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id'        : id,
    'title'     : title,
    'content'   : content,
    'source'    : source,
    'tags'      : tags.join(','),
    'created_at': createdAt.toIso8601String(),
  };
}

class KnowledgeBaseService {
  static final KnowledgeBaseService _i = KnowledgeBaseService._();
  factory KnowledgeBaseService() => _i;
  KnowledgeBaseService._();

  final _db = DatabaseService();
  static const _uuid = Uuid();

  // ════════════════════════════════════════════════════
  //  SEED — initialisation de la base au premier lancement
  // ════════════════════════════════════════════════════
  Future<void> seedIfEmpty() async {
    final database = await _db.db;
    final count = Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) as c FROM knowledge_docs')) ?? 0;
    if (count > 0) return;

    final now = DateTime.now().toIso8601String();
    
    // 1. Importation du seed en dur (kKnowledgeSeed)
    for (final doc in kKnowledgeSeed) {
      final id = _uuid.v4();
      await database.insert('knowledge_docs', {
        'id'        : id,
        'title'     : doc.title,
        'content'   : doc.content,
        'source'    : 'seed',
        'tags'      : doc.tags.join(','),
        'created_at': now,
      });

      // Ajout dans le Vector Store
      try {
        await FlutterGemmaPlugin.instance.addDocument(
          id: id,
          content: '${doc.title}\n${doc.content}',
          metadata: doc.title,
        );
      } catch (e) {
        print("Erreur ajout VectorStore: $e");
      }
    }

    // 2. Importation dynamique des fichiers JSON dans assets/documents/
    try {
      print("--- Recherche de fichiers JSON dans les assets ---");
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      final jsonPaths = manifestMap.keys
          .where((String key) => key.startsWith('assets/documents/') && key.endsWith('.json'))
          .toList();

      for (final path in jsonPaths) {
        print("➡️ Importation automatique de : $path");
        try {
          String jsonString = await rootBundle.loadString(path);
          if (jsonString.startsWith('\ufeff')) {
            jsonString = jsonString.substring(1);
          }
          final dynamic decoded = json.decode(jsonString);
          final List<dynamic> jsonData = decoded is List ? decoded : [decoded];

        int countItems = 0;
        for (final item in jsonData) {
          final id = item['id'] ?? _uuid.v4();
          final title = item['title'] ?? 'Document importé';
          final content = item['full_content'] ?? item['content'] ?? '';
          final source = item['source_file'] ?? path;
          final category = item['category'] ?? '';

          if (content.isEmpty) continue;

          await database.insert('knowledge_docs', {
            'id'        : id,
            'title'     : title,
            'content'   : content,
            'source'    : source,
            'tags'      : category,
            'created_at': now,
          });

          // Vectorisation avec Gecko
          try {
            await FlutterGemmaPlugin.instance.addDocument(
              id: id,
              content: '$title\n$content',
              metadata: title,
            );
          } catch (e) {
            print("Erreur VectorStore JSON ($id): $e");
          }
          
          countItems++;
          if (countItems % 50 == 0) {
            print("... $countItems documents vectorisés depuis $path ...");
          }
        }
        print("✅ Terminé : $countItems documents importés depuis $path !");
        } catch (e) {
          print("⚠️ Erreur fichier $path: $e");
        }
      }
    } catch (e) {
      print("⚠️ Erreur lors du chargement des JSON depuis les assets: $e");
    }
  }

  // ════════════════════════════════════════════════════
  //  CRUD
  // ════════════════════════════════════════════════════
  Future<List<KnowledgeDocument>> getAllDocuments() async {
    final database = await _db.db;
    final rows = await database.query('knowledge_docs', orderBy: 'created_at ASC');
    return rows.map(KnowledgeDocument.fromMap).toList();
  }

  Future<int> getDocumentCount() async {
    final database = await _db.db;
    return Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) as c FROM knowledge_docs')) ?? 0;
  }

  Future<void> deleteDocument(String id) async {
    final database = await _db.db;
    await database.delete('knowledge_docs', where: 'id = ?', whereArgs: [id]);
  }

  /// Importe un texte brut, le découpe en paragraphes (chunks
  /// d'environ [maxWords] mots) et enregistre chaque morceau
  /// comme un document distinct dans la base.
  /// Retourne le nombre de chunks créés.
  Future<int> importTextDocument({
    required String title,
    required String content,
    String source = 'manual',
    int maxWords = 180,
  }) async {
    final database = await _db.db;
    final now = DateTime.now().toIso8601String();
    final chunks = _chunkText(content, maxWords: maxWords);

    for (var i = 0; i < chunks.length; i++) {
      final id = _uuid.v4();
      final chunkTitle = chunks.length > 1 ? '$title (${i + 1}/${chunks.length})' : title;
      
      await database.insert('knowledge_docs', {
        'id'        : id,
        'title'     : chunkTitle,
        'content'   : chunks[i],
        'source'    : source,
        'tags'      : '',
        'created_at': now,
      });

      // Ajout dans le Vector Store
      try {
        await FlutterGemmaPlugin.instance.addDocument(
          id: id,
          content: '$chunkTitle\n${chunks[i]}',
          metadata: title,
        );
      } catch (e) {
        print("Erreur ajout VectorStore: $e");
      }
    }
    return chunks.length;
  }

  List<String> _chunkText(String text, {required int maxWords}) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      final trimmed = text.trim();
      return trimmed.isEmpty ? [] : [trimmed];
    }

    final chunks = <String>[];
    var buffer = <String>[];
    var wordCount = 0;

    for (final p in paragraphs) {
      final words = p.split(RegExp(r'\s+')).length;
      if (wordCount + words > maxWords && buffer.isNotEmpty) {
        chunks.add(buffer.join('\n\n'));
        buffer = [];
        wordCount = 0;
      }
      buffer.add(p);
      wordCount += words;
    }
    if (buffer.isNotEmpty) chunks.add(buffer.join('\n\n'));
    return chunks;
  }

  // ════════════════════════════════════════════════════
  //  RECHERCHE — Vector Store (Gecko)
  // ════════════════════════════════════════════════════
  Future<List<KnowledgeDocument>> search(String query, {int topK = 3}) async {
    try {
      final results = await FlutterGemmaPlugin.instance.searchSimilar(
        query: query,
        topK: topK,
      );

      return results.map((r) => KnowledgeDocument(
        id: r.id,
        title: r.metadata ?? 'Source experte',
        content: r.content,
        source: 'vector_store',
        tags: [],
        createdAt: DateTime.now(),
      )).toList();
    } catch (e) {
      print("Erreur Vector Store search: $e");
      return [];
    }
  }
}