import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';
import '../data/knowledge_seed.dart';

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

  // Mots vides français ignorés lors de l'indexation/recherche
  static const _stopwords = {
    'les','des','est','que','qui','pour','avec','dans','une','sur','mon',
    'mes','vos','votre','sont','quoi','comment','quand','quel','quelle',
    'plus','tout','tous','ses','par','aux','cette','ces','son',
    'leur','leurs','nos','notre','sera','peut','peux','faire',
    'avoir','être','etre','tres','très','aussi','donc','mais','ou','et',
    'au','de','du','la','le','un','en','ne','pas','vous','je',
  };

  // ════════════════════════════════════════════════════
  //  SEED — initialisation de la base au premier lancement
  // ════════════════════════════════════════════════════
  Future<void> seedIfEmpty() async {
    final database = await _db.db;
    final count = Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) as c FROM knowledge_docs')) ?? 0;
    if (count > 0) return;

    final now = DateTime.now().toIso8601String();
    for (final doc in kKnowledgeSeed) {
      await database.insert('knowledge_docs', {
        'id'        : _uuid.v4(),
        'title'     : doc.title,
        'content'   : doc.content,
        'source'    : 'seed',
        'tags'      : doc.tags.join(','),
        'created_at': now,
      });
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
      await database.insert('knowledge_docs', {
        'id'        : _uuid.v4(),
        'title'     : chunks.length > 1 ? '$title (${i + 1}/${chunks.length})' : title,
        'content'   : chunks[i],
        'source'    : source,
        'tags'      : '',
        'created_at': now,
      });
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
  //  RECHERCHE — TF-IDF léger, sans embeddings
  // ════════════════════════════════════════════════════
  Future<List<KnowledgeDocument>> search(String query, {int topK = 3}) async {
    final docs = await getAllDocuments();
    if (docs.isEmpty) return [];

    final queryTerms = _tokenize(query).toSet();
    if (queryTerms.isEmpty) return [];

    // Document frequency (df) de chaque terme à travers la base
    final df = <String, int>{};
    final docTermFreqs = <String, Map<String, int>>{};

    for (final doc in docs) {
      final terms = _tokenize('${doc.title} ${doc.content} ${doc.tags.join(' ')}');
      final tf = <String, int>{};
      for (final t in terms) tf[t] = (tf[t] ?? 0) + 1;
      docTermFreqs[doc.id] = tf;
      for (final t in tf.keys) df[t] = (df[t] ?? 0) + 1;
    }

    final n = docs.length;
    final scored = <MapEntry<KnowledgeDocument, double>>[];

    for (final doc in docs) {
      final tf = docTermFreqs[doc.id]!;
      double score = 0;
      for (final qt in queryTerms) {
        final f = tf[qt] ?? 0;
        if (f == 0) continue;
        final idf = log((n + 1) / (1 + (df[qt] ?? 0))) + 1;
        score += f * idf;
      }
      if (score > 0) scored.add(MapEntry(doc, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(topK).map((e) => e.key).toList();
  }

  // ── Tokenisation : minuscules, sans accents, sans ponctuation,
  //    sans mots vides, mots de 3+ caractères ──────────────────
  List<String> _tokenize(String text) {
    final normalized = _removeAccents(text.toLowerCase());
    final cleaned = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopwords.contains(w))
        .toList();
  }

  String _removeAccents(String s) {
    const from = 'àâäáãåèéêëìíîïòóôõöùúûüçñ';
    const to   = 'aaaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s;
  }
}