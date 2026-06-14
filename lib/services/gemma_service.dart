import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service singleton pour Gemma 4 LiteRT-LM.
/// 
/// Le modèle est chargé une seule fois (GPU shaders en cache),
/// mais chaque requête d'analyse crée une session de chat isolée
/// pour éviter la pollution du contexte.
class GemmaService {
  static final GemmaService _instance = GemmaService._internal();
  factory GemmaService() => _instance;
  GemmaService._internal();

  InferenceModel? _model;
  bool isInitialized = false;

  // Session persistante pour le chat conversationnel
  InferenceChat? _persistentChatSession;

  Future<void> initAI() async {
    if (isInitialized) return;

    try {
      print("--- Demande de permissions de stockage ---");
      if (Platform.isAndroid) {
        if (!await Permission.manageExternalStorage.isGranted) {
          await Permission.manageExternalStorage.request();
        }
        if (!await Permission.storage.isGranted) {
          await Permission.storage.request();
        }
      }

      print("--- ÉTAPE 1 : Pointage vers le dossier Download public ---");
      const modelPath = '/storage/emulated/0/Download/gemma-4-E2B-it.litertlm';

      final file = File(modelPath);
      if (!await file.exists()) {
        print("❌ Fichier introuvable : $modelPath");
        return;
      }

      print("--- ÉTAPE 2 : Chargement de Gemma ---");
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(modelPath).install();

      print("--- ÉTAPE 3 : Allocation GPU ---");
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 4096,
        preferredBackend: PreferredBackend.gpu,
      );

      isInitialized = true;
      print("🚀 IA Gemma chargée avec succès (GPU) !");

    } catch (e) {
      print("❌ Erreur de chargement Gemma : $e");
    }
  }

  // ══════════════════════════════════════════════════════
  //  ANALYSE ONE-SHOT (pour le diagnostic agronomique)
  //  → Session jetable = pas de pollution de contexte
  // ══════════════════════════════════════════════════════

  Future<String> sendOneShot(String prompt) async {
    if (!isInitialized || _model == null) return "IA non initialisée";

    try {
      // Créer une session isolée pour chaque requête
      final session = await _model!.createChat(
        systemInstruction: "Tu es un expert agronome. Réponds UNIQUEMENT en JSON valide, sans markdown.",
      );

      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final response = await session.generateChatResponse();

      if (response is TextResponse) {
        return response.token.isNotEmpty ? response.token : "Pas de réponse.";
      }
      return "Pas de réponse.";
    } catch (e) {
      return "Erreur : $e";
    }
  }

  // ══════════════════════════════════════════════════════
  //  CHAT CONVERSATIONNEL (pour le chat avec l'utilisateur)
  //  → Session persistante = mémoire de la conversation
  // ══════════════════════════════════════════════════════

  /// Crée ou récupère une session de chat persistante
  Future<void> _ensureChatSession(String systemPrompt) async {
    if (_persistentChatSession == null) {
      _persistentChatSession = await _model!.createChat(
        systemInstruction: systemPrompt,
      );
    }
  }

  /// Envoie un message dans le chat conversationnel (avec mémoire)
  Future<String> sendChatMessage(String message, {String? systemPrompt}) async {
    if (!isInitialized || _model == null) return "IA non initialisée";

    try {
      await _ensureChatSession(
        systemPrompt ?? _defaultChatSystemPrompt,
      );

      await _persistentChatSession!.addQueryChunk(
        Message.text(text: message, isUser: true),
      );
      final response = await _persistentChatSession!.generateChatResponse();

      if (response is TextResponse) {
        return response.token.isNotEmpty ? response.token : "Pas de réponse.";
      }
      return "Pas de réponse.";
    } catch (e) {
      print("❌ Erreur chat Gemma : $e");
      return "Erreur de l'IA locale. Réessayez.";
    }
  }

  /// Réinitialise la session de chat (nouvelle conversation)
  void resetChatSession() {
    _persistentChatSession = null;
  }

  /// Ancien sendMessage redirigé vers sendOneShot pour compatibilité
  Future<String> sendMessage(String prompt) => sendOneShot(prompt);

  static const String _defaultChatSystemPrompt = '''
Tu es l'Assistant AgriScan, un expert agronome IA chaleureux et compétent.
Tu réponds en français, de façon claire et concise (4 à 6 phrases).
Tu es spécialisé dans les cultures africaines et méditerranéennes.
Si tu ne sais pas, dis-le honnêtement.
N'invente jamais de noms de produits chimiques non vérifiés.
Reste toujours dans le domaine agricole.
''';
}
