import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'database_service.dart';
import 'knowledge_base_service.dart';
import '../config/secrets.dart';

// ══════════════════════════════════════════════════════════
//  CHAT SERVICE — multi-conversations
//  Assistant agronome conversationnel (Groq) enrichi par :
//  - le contexte agricole de l'utilisateur (région, culture...)
//  - son dernier diagnostic AgriScan (si disponible)
//  - la base de connaissances RAG (KnowledgeBaseService)
//  Chaque échange appartient à une ChatConversation, listée
//  et gérable depuis le panneau latéral (ChatHistoryDrawer).
// ══════════════════════════════════════════════════════════

class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final List<String> sources; // titres des docs RAG utilisés (assistant)
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sources = const [],
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id     : m['id'] as String,
    role   : m['role'] as String,
    content: m['content'] as String,
    sources: (m['sources'] as String? ?? '')
        .split('|||').where((s) => s.isNotEmpty).toList(),
    createdAt: DateTime.parse(
        m['created_at'] as String? ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toMap() => {
    'id'        : id,
    'role'      : role,
    'content'   : content,
    'sources'   : sources.join('|||'),
    'created_at': createdAt.toIso8601String(),
  };
}

// ── Conversation (fil de discussion) ───────────────────────
class ChatConversation {
  final String id;
  final String title;       // vide tant qu'aucun message n'a été envoyé
  final String? preview;     // aperçu du dernier message
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatConversation({
    required this.id,
    required this.title,
    this.preview,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : 'Nouvelle conversation';

  factory ChatConversation.fromMap(Map<String, dynamic> m) => ChatConversation(
    id       : m['id'] as String,
    title    : m['title'] as String? ?? '',
    preview  : m['last_message'] as String?,
    createdAt: DateTime.parse(
        m['created_at'] as String? ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(
        m['updated_at'] as String? ?? DateTime.now().toIso8601String()),
  );
}

// ── Contexte agricole + dernier diagnostic injectés dans le prompt ──
class ChatContext {
  final String region, culture, climate, soil, season;
  final String? lastScanDisease;   // libellé FR, ex: "Rouille commune"
  final String? lastScanPlant;
  final String? lastScanDate;      // ex: "13/06"
  final double? lastScanConfidence;

  const ChatContext({
    required this.region,
    required this.culture,
    required this.climate,
    required this.soil,
    required this.season,
    this.lastScanDisease,
    this.lastScanPlant,
    this.lastScanDate,
    this.lastScanConfidence,
  });
}

class ChatService {
  static final ChatService _i = ChatService._();
  factory ChatService() => _i;
  ChatService._();

  final _db = DatabaseService();
  final _kb = KnowledgeBaseService();
  static const _uuid = Uuid();

  static const String _url   = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';
  static String get _key => Secrets.groqApiKey;

  // ════════════════════════════════════════════════════
  //  CONVERSATIONS
  // ════════════════════════════════════════════════════

  /// Crée une nouvelle conversation vide et retourne son id.
  /// Le titre sera généré automatiquement à partir du premier
  /// message envoyé.
  Future<String> createConversation() async {
    final database = await _db.db;
    final id  = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await database.insert('chat_conversations', {
      'id'        : id,
      'title'     : '',
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  /// Liste toutes les conversations, plus récentes en premier,
  /// avec un aperçu du dernier message.
  Future<List<ChatConversation>> listConversations() async {
    final database = await _db.db;
    final rows = await database.rawQuery('''
      SELECT c.id, c.title, c.created_at, c.updated_at,
             (SELECT content FROM chat_messages
                WHERE conversation_id = c.id
                ORDER BY created_at DESC LIMIT 1) as last_message
      FROM chat_conversations c
      ORDER BY c.updated_at DESC
    ''');
    return rows.map(ChatConversation.fromMap).toList();
  }

  Future<void> renameConversation(String id, String title) async {
    final database = await _db.db;
    await database.update('chat_conversations', {'title': title},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteConversation(String id) async {
    final database = await _db.db;
    await database.delete('chat_messages',
        where: 'conversation_id = ?', whereArgs: [id]);
    await database.delete('chat_conversations',
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final database = await _db.db;
    final rows = await database.query('chat_messages',
        where: 'conversation_id = ?', whereArgs: [conversationId],
        orderBy: 'created_at ASC');
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> _persist(String conversationId, ChatMessage msg) async {
    final database = await _db.db;
    final map = msg.toMap();
    map['conversation_id'] = conversationId;
    await database.insert('chat_messages', map);
  }

  /// Donne un titre à la conversation à partir du premier message
  /// (si elle n'en a pas encore).
  Future<void> _maybeSetTitle(String conversationId, String firstMessage) async {
    final database = await _db.db;
    final rows = await database.query('chat_conversations',
        columns: ['title'], where: 'id = ?', whereArgs: [conversationId]);
    if (rows.isEmpty) return;
    final current = (rows.first['title'] as String?) ?? '';
    if (current.trim().isEmpty) {
      var title = firstMessage.trim().replaceAll('\n', ' ');
      if (title.length > 48) title = '${title.substring(0, 48)}…';
      await database.update('chat_conversations', {'title': title},
          where: 'id = ?', whereArgs: [conversationId]);
    }
  }

  Future<void> _touchConversation(String conversationId) async {
    final database = await _db.db;
    await database.update('chat_conversations',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [conversationId]);
  }

  // ════════════════════════════════════════════════════
  //  ENVOI D'UN MESSAGE
  // ════════════════════════════════════════════════════
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String text,
    required List<ChatMessage> history,
    required ChatContext context,
  }) async {
    // Persiste le message utilisateur + titre auto + horodatage
    final userMsg = ChatMessage(
        id: _uuid.v4(), role: 'user', content: text, createdAt: DateTime.now());
    await _persist(conversationId, userMsg);
    await _maybeSetTitle(conversationId, text);
    await _touchConversation(conversationId);

    // Récupération RAG
    final relevant = await _kb.search(text, topK: 3);
    final systemPrompt = _buildSystemPrompt(context, relevant);

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': text},
    ];

    String content;
    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type' : 'application/json',
          'Authorization': 'Bearer $_key',
        },
        body: jsonEncode({
          'model'      : _model,
          'messages'   : messages,
          'temperature': 0.4,
          'max_tokens' : 700,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        content = (data['choices'][0]['message']['content'] as String).trim();
      } else {
        content = 'Désolé, je n\'ai pas pu contacter le service IA '
            '(erreur ${response.statusCode}). Réessayez dans un instant.';
      }
    } catch (e) {
      content = 'Connexion impossible. Vérifiez votre connexion internet '
          'et réessayez.';
    }

    final reply = ChatMessage(
      id        : _uuid.v4(),
      role      : 'assistant',
      content   : content,
      sources   : relevant.map((d) => d.title).toList(),
      createdAt : DateTime.now(),
    );
    await _persist(conversationId, reply);
    await _touchConversation(conversationId);
    return reply;
  }

  // ════════════════════════════════════════════════════
  //  PROMPT SYSTÈME
  // ════════════════════════════════════════════════════
  String _buildSystemPrompt(ChatContext ctx, List<KnowledgeDocument> docs) {
    final docsBlock = docs.isEmpty
        ? ''
        : docs.map((d) => '### ${d.title}\n${d.content}').join('\n\n');

    final lastScanBlock = ctx.lastScanDisease != null
        ? '\nDERNIER DIAGNOSTIC AGRISCAN : ${ctx.lastScanDisease}'
        '${ctx.lastScanPlant != null ? ' sur ${ctx.lastScanPlant}' : ''}'
        '${ctx.lastScanConfidence != null
        ? ' (confiance ${(ctx.lastScanConfidence! * 100).round()}%)'
        : ''}'
        '${ctx.lastScanDate != null ? ', le ${ctx.lastScanDate}' : ''}.\n'
        : '';

    final knowledgeBlock = docsBlock.isNotEmpty
        ? '\nBASE DE CONNAISSANCES PERTINENTE '
        '(à utiliser en priorité, ne la contredis pas) :\n$docsBlock\n'
        : '';

    return '''
Tu es l'Assistant AgriScan, un expert agronome IA spécialisé dans les
cultures de la région ${ctx.region}.
Tu réponds aux agriculteurs en français, de façon chaleureuse, claire et
concise (4 à 6 phrases, sauf si l'utilisateur demande plus de détails).

CONTEXTE DE L'AGRICULTEUR :
- Région : ${ctx.region}
- Culture principale : ${ctx.culture}
- Climat : ${ctx.climate}
- Type de sol : ${ctx.soil}
- Saison : ${ctx.season}
$lastScanBlock$knowledgeBlock
RÈGLES :
- Si la question porte sur une maladie présente dans la base de
  connaissances ci-dessus, base ta réponse STRICTEMENT sur ces
  informations (nature fongique/virale, agent pathogène, traitement).
- Si tu ne sais pas, dis-le honnêtement et conseille de consulter un
  technicien agricole local.
- N'invente jamais de noms de produits chimiques non vérifiés.
- Reste toujours dans le domaine agricole.
''';
  }
}