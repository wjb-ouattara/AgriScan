import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'database_service.dart';
import 'knowledge_base_service.dart';
import '../config/secrets.dart';

// ══════════════════════════════════════════════════════════
//  CHAT SERVICE
//  Assistant agronome conversationnel (Groq) enrichi par :
//  - le contexte agricole de l'utilisateur (région, culture...)
//  - son dernier diagnostic AgriScan (si disponible)
//  - la base de connaissances RAG (KnowledgeBaseService)
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
  //  HISTORIQUE (persistance SQLite)
  // ════════════════════════════════════════════════════
  Future<List<ChatMessage>> loadHistory({int limit = 100}) async {
    final database = await _db.db;
    final rows = await database.query(
        'chat_messages', orderBy: 'created_at ASC', limit: limit);
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> clearHistory() async {
    final database = await _db.db;
    await database.delete('chat_messages');
  }

  Future<void> _persist(ChatMessage msg) async {
    final database = await _db.db;
    await database.insert('chat_messages', msg.toMap());
  }

  // ════════════════════════════════════════════════════
  //  ENVOI D'UN MESSAGE
  // ════════════════════════════════════════════════════
  Future<ChatMessage> sendMessage({
    required String text,
    required List<ChatMessage> history,
    required ChatContext context,
  }) async {
    // Persiste le message utilisateur
    final userMsg = ChatMessage(
        id: _uuid.v4(), role: 'user', content: text, createdAt: DateTime.now());
    await _persist(userMsg);

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
    await _persist(reply);
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