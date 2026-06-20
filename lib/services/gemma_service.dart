import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

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

      print("--- ÉTAPE 1 : Préparation du modèle ---");
      final publicPath = '/storage/emulated/0/Download/gemma-4-E2B-it.litertlm';
      final appDocsDir = await getApplicationDocumentsDirectory();
      final internalPath = '${appDocsDir.path}/gemma-4-E2B-it.litertlm';

      if (!File(internalPath).existsSync()) {
        print(" Copie du modèle vers le stockage interne (cela peut prendre 10 à 30 secondes)...");
        final publicFile = File(publicPath);
        if (!publicFile.existsSync()) {
          print(" Fichier introuvable dans Download : $publicPath");
          return;
        }
        await publicFile.copy(internalPath);
        print(" Copie terminée !");
      } else {
        print(" Le modèle est déjà dans le stockage interne.");
      }

      print("--- ÉTAPE 2 : Chargement de Gemma ---");
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(internalPath).install();

      print("--- ÉTAPE 3 : Allocation GPU ---");
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 4096,
        preferredBackend: PreferredBackend.gpu,
      );

      print("--- ÉTAPE 4 : Initialisation Vector Store (Gecko) ---");
      final hasGecko = await FlutterGemma.isModelInstalled('Gecko_256_quant.tflite');
      if (!hasGecko) {
        print(" Téléchargement du modèle Gecko (requis 1ère fois uniquement)...");
        await FlutterGemma.installEmbedder()
            .modelFromNetwork('https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/Gecko_256_quant.tflite')
            .tokenizerFromNetwork('https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/sentencepiece.model')
            .install();
        print(" Gecko téléchargé avec succès !");
      } else {
        print(" Modèle Gecko déjà présent, chargement hors-ligne.");
        final appDocsDir = await getApplicationDocumentsDirectory();
        await FlutterGemma.installEmbedder()
            .modelFromFile('${appDocsDir.path}/Gecko_256_quant.tflite')
            .tokenizerFromFile('${appDocsDir.path}/sentencepiece.model')
            .install();
      }
      await FlutterGemmaPlugin.instance.initializeVectorStore('rag_store');

      isInitialized = true;
      print(" IA Gemma et Vector Store chargés avec succès !");

    } catch (e) {
      print(" Erreur de chargement Gemma : $e");
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
      final session = await _model!.openChat(
        systemInstruction: "Tu es un expert agronome. Réponds UNIQUEMENT en JSON valide, sans markdown.",
      );

      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final response = await session.generateChatResponse();
      await session.session.close();

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
      _persistentChatSession = await _model!.openChat(
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
      print(" Erreur chat Gemma : $e");
      return "Erreur de l'IA locale. Réessayez.";
    }
  }

  /// Réinitialise la session de chat (nouvelle conversation)
  void resetChatSession() {
    _persistentChatSession?.session.close();
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
